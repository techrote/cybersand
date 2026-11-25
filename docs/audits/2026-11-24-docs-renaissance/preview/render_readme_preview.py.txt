#!/usr/bin/env python3
"""Static README layout approximation: Pandoc GFM -> HTML -> PyMuPDF Story.

This is not GitHub browser rendering or an application capture. Run from the
repository root with: python3 <script> --repo-root . --output <audit-preview-dir>
Narrow printed code blocks wrap; GitHub may use horizontal scrolling.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import datetime
import fitz

CSS = """
body { font-family: sans-serif; font-size: 16px; line-height: 1.5; color: #24292f; margin: 0; }
h1 { font-size: 34px; line-height: 1.2; margin: 0 0 16px 0; }
h2 { font-size: 26px; line-height: 1.25; margin: 28px 0 18px 0; padding-bottom: 8px; border-bottom: 1px solid #d0d7de; }
p { margin: 0 0 16px 0; }
a { color: #0969da; }
em { color: #57606a; }
img { width: 100%; height: auto; }
table { width: 100%; border-collapse: collapse; margin: 0 0 18px 0; font-size: 14px; line-height: 1.5; }
th, td { border: 1px solid #d0d7de; padding: 8px 10px; vertical-align: top; }
th { background-color: #f6f8fa; font-weight: bold; text-align: left; }
pre { background-color: #f6f8fa; padding: 14px; font-family: monospace; font-size: 13px; line-height: 1.5; white-space: pre-wrap; overflow-wrap: anywhere; }
code { font-family: monospace; font-size: 13px; }
"""

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = args.repo_root.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source = root / 'README.md'
    html = subprocess.check_output(['pandoc','--from=gfm','--to=html5',str(source)], cwd=root, text=True)
    # Suppress line-anchor markup inside source blocks; retain visible code text.
    html = re.sub(r'<a href="#[^"]+" aria-hidden="true" tabindex="-1"></a>', '', html)
    previous = None
    old_manifest = output / 'manifest.json'
    if old_manifest.exists():
        old = json.loads(old_manifest.read_text())
        previous = old.get('previous_source_sha256', old.get('source_sha256'))
    previews = []
    for name, width, margin in [('desktop',960,48),('narrow',390,36)]:
        story = fitz.Story(html=html, user_css=CSS, archive=fitz.Archive(str(root)))
        more, filled = story.place(fitz.Rect(margin, margin, width-margin, 50000))
        if more:
            raise RuntimeError('README exceeds bounded static preview page')
        height = math.ceil(fitz.Rect(filled).y1 + margin)
        story.reset()
        pdf_path = output / f'readme-{name}.pdf'
        writer = fitz.DocumentWriter(str(pdf_path))
        device = writer.begin_page(fitz.Rect(0,0,width,height))
        more, actual = story.place(fitz.Rect(margin, margin, width-margin, height-margin))
        if more:
            raise RuntimeError('Measured layout no longer fits')
        story.draw(device)
        writer.end_page()
        writer.close()
        doc = fitz.open(pdf_path)
        packed = pdf_path.with_suffix('.compressed.pdf')
        doc.save(packed, garbage=4, deflate=True)
        doc.close()
        packed.replace(pdf_path)
        doc = fitz.open(pdf_path)
        page = doc[0]
        top_path = output / f'readme-{name}-top.png'
        page.get_pixmap(matrix=fitz.Matrix(1,1),clip=fitz.Rect(0,0,width,min(height,1450)),alpha=False).save(top_path)
        gallery_start = page.search_for('A few places to explore')
        gallery_end = page.search_for('Start on desktop')
        if not gallery_start or not gallery_end:
            raise RuntimeError('Gallery landmarks missing from rendered PDF')
        gallery_path = output / f'readme-{name}-gallery.png'
        y0 = max(0, gallery_start[0].y0 - 20)
        y1 = min(height, gallery_end[0].y0 + 45)
        page.get_pixmap(matrix=fitz.Matrix(1,1),clip=fitz.Rect(0,y0,width,y1),alpha=False).save(gallery_path)
        extracted = ' '.join(page.get_text().split())
        if 'individually' not in extracted or 'loaded district tiles' not in extracted:
            raise RuntimeError('Current Neon caption missing from preview text')
        previews.append({'name':name,'width':width,'height':height,'margin':margin,
            'pdf':pdf_path.name,'top_png':top_path.name,'gallery_png':gallery_path.name,
            'pdf_sha256':digest(pdf_path),'bytes':pdf_path.stat().st_size,
            'top_png_sha256':digest(top_path),'gallery_png_sha256':digest(gallery_path)})
        doc.close()
    manifest = {'source':'README.md','source_sha256':digest(source),
        'recorded_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'previous_source_sha256':previous,
        'renderer':f'pandoc --from=gfm --to=html5 plus PyMuPDF Story {fitz.VersionBind}',
        'scope':'Static Markdown layout approximation, not actual GitHub browser rendering. Narrow code blocks wrap for printed review; GitHub may scroll them. No application capture or physical GPU claim.',
        'pdf_processing':'Lossless stream deflate; source PNG pixels are retained.',
        'style_note':'Reconstructed consistent 960/390 widths, 48/36 margins and sans-serif16 body after caption correction; original one-off CSS was not retained.',
        'reproduction_script':'render_readme_preview.py.txt','previews':previews}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))

if __name__ == '__main__':
    main()
