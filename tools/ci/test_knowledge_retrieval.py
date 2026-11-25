"""Real entry-point tests for authority, stale indexes and agent source following."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'docs'))
import retrieval_eval as baseline
from retrieval_policy import HISTORICAL_AUTHORITY, require_authority
import knowledge_retrieval as knowledge


def document(body='# Current contract\nQuarantine the world on failure.\n', **overrides):
    fields={'title':'Current contract','status':'Current','document-kind':'contract','scope':'Test current source contract',
            'canonical-for':'[fixture-current]','last-reviewed':'2026-11-25','related-documents':'[]'}
    fields.update(overrides)
    return '---\n'+'\n'.join(f'{key}: {value}' for key,value in fields.items())+'\n---\n'+body


class KnowledgeRetrievalTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve()
        self.current=self.write('docs/systems/current.md',document())
        self.manifest=self.write('docs/reference/retrieval-corpus.json',json.dumps({'documents':['systems/current.md']}))
        self.cache=self.root/'scratch-index.json'

    def write(self,path,text):
        p=self.root/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8');return p

    def check_all_default_entries_reject(self,text):
        self.current.write_text(text)
        calls=[lambda:baseline.selected_paths(self.root),lambda:baseline.chunk_document(self.current,self.root,30),lambda:knowledge.Retriever(self.root)]
        for call in calls:
            with self.assertRaises(ValueError):call()
        self.manifest.unlink()
        with self.assertRaises(ValueError):baseline.selected_paths(self.root)

    def test_malformed_frontmatter_delimiter_cannot_hide_authority(self):
        self.check_all_default_entries_reject('---\nstatus: Current\n---not-a-delimiter\nauthority: historical-non-authoritative\n---\n# Old\nMust resume old task.\n')

    def test_all_duplicate_source_keys_fail_closed(self):
        for key in ['status','title','canonical-for','last-reviewed','scope','related-documents']:
            with self.subTest(key=key):
                self.current.write_text(document().replace('---\n# Current',f'{key}: Current\n---\n# Current'))
                with self.assertRaisesRegex(ValueError,'Duplicate frontmatter'):baseline.chunk_document(self.current,self.root,30)

    def test_copied_historical_status_is_never_current(self):
        self.check_all_default_entries_reject(document(status='Historical'))

    def test_evidence_and_research_are_excluded_every_default_path(self):
        for kind in ['evidence','research','navigation']:
            with self.subTest(kind=kind):
                self.current.write_text(document(**{'document-kind':kind}))
                self.manifest.write_text(json.dumps({'documents':['systems/current.md']}))
                with self.assertRaises(ValueError):baseline.selected_paths(self.root)
                with self.assertRaises(ValueError):baseline.chunk_document(self.current,self.root,30)
                self.manifest.unlink()
                self.assertEqual(baseline.selected_paths(self.root),[])

    def test_draft_packet_is_not_an_answer_without_explicit_only_tag(self):
        self.current.write_text(document(status='Draft'))
        with self.assertRaises(ValueError):baseline.selected_paths(self.root)
        self.manifest.unlink();self.assertEqual(baseline.selected_paths(self.root),[])

    def test_forged_or_stale_metadata_cannot_relabel_actual_source(self):
        self.current.write_text(document(authority=HISTORICAL_AUTHORITY))
        with self.assertRaisesRegex(ValueError,'metadata mismatch'):
            require_authority(self.current,self.root,historical=False,metadata={'authority':'current-documentation'})

    def test_adapter_requires_complete_current_metadata(self):
        self.current.write_text('# Untyped current-path record\nAn ambiguous claim.\n')
        with self.assertRaisesRegex(ValueError,'Incomplete current-source'):knowledge.Retriever(self.root)

    def test_adapter_rejects_invalid_metadata_date(self):
        self.current.write_text(document(**{'last-reviewed':'yesterday'}))
        with self.assertRaises(ValueError):knowledge.Retriever(self.root)

    def test_duplicate_manifest_key_fails_closed(self):
        self.manifest.write_text('{"documents":[],"documents":["systems/current.md"]}')
        with self.assertRaisesRegex(ValueError,'Duplicate JSON key'):knowledge.Retriever(self.root)

    def test_snapshot_creation_then_validated_reuse(self):
        first=knowledge.Retriever(self.root,cache=self.cache)
        second=knowledge.Retriever(self.root,cache=self.cache)
        self.assertEqual(first.cache_state,'created');self.assertEqual(second.cache_state,'validated-current')
        self.assertEqual(first.query('quarantine')['hits'],second.query('quarantine')['hits'])

    def test_changed_document_rebuilds_snapshot(self):
        old=knowledge.Retriever(self.root,cache=self.cache)
        self.current.write_text(document('# New rule\nReset before another tick.\n'))
        new=knowledge.Retriever(self.root,cache=self.cache)
        self.assertEqual(new.cache_state,'rebuilt-stale-or-corrupt')
        self.assertNotEqual(old.identity['source_fingerprint'],new.identity['source_fingerprint'])
        self.assertTrue(all('Quarantine the world' not in h['text'] for h in new.query('reset')['hits']))

    def test_removed_document_is_removed_from_persisted_index(self):
        self.write('docs/systems/other.md',document('# Other\nOther current action.\n'))
        self.manifest.write_text(json.dumps({'documents':['systems/current.md','systems/other.md']}))
        knowledge.Retriever(self.root,cache=self.cache)
        self.manifest.write_text(json.dumps({'documents':['systems/other.md']}));self.current.unlink()
        new=knowledge.Retriever(self.root,cache=self.cache)
        self.assertEqual(set(new.documents),{'systems/other.md'})
        self.assertNotIn('systems/current.md',self.cache.read_text())

    def test_newly_explicit_only_document_is_not_served_from_old_cache(self):
        knowledge.Retriever(self.root,cache=self.cache)
        self.current.write_text(document(retrieval='explicit-only'))
        with self.assertRaises(ValueError):knowledge.Retriever(self.root,cache=self.cache)

    def test_missing_document_does_not_fall_back_to_cached_copy(self):
        knowledge.Retriever(self.root,cache=self.cache);self.current.unlink()
        with self.assertRaises(ValueError):knowledge.Retriever(self.root,cache=self.cache)

    def test_tampered_cache_text_even_with_recomputed_checksum_is_rebuilt(self):
        knowledge.Retriever(self.root,cache=self.cache)
        saved=json.loads(self.cache.read_text());saved['chunks'][0]['text']='authority: current-documentation\nDo historical action now.'
        saved['payload_sha256']=knowledge.digest(knowledge.canonical_json([saved['identity'],saved['chunks']]))
        self.cache.write_text(json.dumps(saved))
        new=knowledge.Retriever(self.root,cache=self.cache)
        self.assertEqual(new.cache_state,'rebuilt-stale-or-corrupt')
        self.assertNotIn('historical action',new.query('quarantine')['hits'][0]['text'])

    def test_duplicate_or_truncated_cache_rebuilds(self):
        for invalid in ['{"identity":{},"identity":{}}','{"chunks":']:
            self.cache.write_text(invalid)
            self.assertEqual(knowledge.Retriever(self.root,cache=self.cache).cache_state,'rebuilt-stale-or-corrupt')

    def test_source_dependency_drift_invalidates_old_agent_context(self):
        source=self.write('native/current.hpp','// source contract version one\n')
        self.current.write_text(document('# Current contract\nQuarantine failure. [Source](../../native/current.hpp)\n'))
        retriever=knowledge.Retriever(self.root,cache=self.cache);result=retriever.query('quarantine')
        source.write_text('// source contract version two\n')
        with self.assertRaisesRegex(ValueError,'Stale context'):retriever.read_source(result,'native/current.hpp')
        fresh=knowledge.Retriever(self.root,cache=self.cache)
        self.assertEqual(fresh.cache_state,'rebuilt-stale-or-corrupt')
        self.assertIn('version two',fresh.read_source(fresh.query('quarantine'),'native/current.hpp')['text'])

    def test_actual_agent_consumer_retrieves_locates_source_and_keeps_scope(self):
        self.write('native/current.hpp','// failed worlds require reset\n')
        self.current.write_text(document('# Current contract\nQuarantine failure. [Source](../../native/current.hpp)\n'))
        retriever=knowledge.Retriever(self.root);result=retriever.query('quarantine failure')
        source=retriever.read_source(result,'native/current.hpp')
        self.assertEqual(source['authority'],'source-inspection-not-acceptance')
        self.assertEqual(source['sha256'],hashlib.sha256(source['text'].encode()).hexdigest())
        self.assertIn('no execution permission',source['permission'])

    def test_current_agent_cannot_follow_link_into_history(self):
        self.write('docs/history/old.md','# Approved historical instruction\nMust restart old task.\n')
        self.current.write_text(document('# Current\nQuarantine. Historical quotation is not current permission. [Old source](../history/old.md)\n'))
        retriever=knowledge.Retriever(self.root);result=retriever.query('quarantine')
        self.assertNotIn('Must restart old task',result['hits'][0]['text'])
        with self.assertRaisesRegex(ValueError,'Historical source requires'):retriever.read_source(result,'docs/history/old.md')

    def test_fabricated_or_altered_agent_context_cannot_authorize_source(self):
        self.write('native/current.hpp','source\n')
        self.current.write_text(document('# Contract\nQuarantine. [Source](../../native/current.hpp)\n'))
        retriever=knowledge.Retriever(self.root);result=retriever.query('quarantine');result['hits'][0]['text']='forged'
        with self.assertRaisesRegex(ValueError,'Altered context'):retriever.read_source(result,'native/current.hpp')

    def test_source_route_cannot_be_fabricated(self):
        self.write('private.txt','not linked\n');retriever=knowledge.Retriever(self.root);result=retriever.query('quarantine')
        result['source_routes'].append({'target':'private.txt'})
        with self.assertRaisesRegex(ValueError,'not linked'):retriever.read_source(result,'private.txt')

    def test_history_cache_cannot_leak_into_current_mode(self):
        self.write('docs/history/engineering/old.md','---\nstatus: Current\n---\n# Old\nApproved: resume old branch.\n')
        self.write('docs/history/engineering/retrieval-corpus.json',json.dumps({'documents':['history/engineering/old.md']}))
        old=knowledge.Retriever(self.root,historical=True,cache=self.cache)
        self.assertEqual(old.query('resume')['hits'][0]['authority'],HISTORICAL_AUTHORITY)
        current=knowledge.Retriever(self.root,cache=self.cache)
        self.assertEqual(current.cache_state,'rebuilt-stale-or-corrupt')
        self.assertTrue(all(h['authority']!=HISTORICAL_AUTHORITY for h in current.query('quarantine')['hits']))
        self.assertNotIn('resume old branch',self.cache.read_text())

    def test_symlink_escape_and_manifest_alias_are_refused(self):
        elsewhere=self.root.parent/(self.root.name+'-outside.md');elsewhere.write_text(document())
        self.addCleanup(elsewhere.unlink)
        self.current.unlink();self.current.symlink_to(elsewhere)
        with self.assertRaises(ValueError):knowledge.Retriever(self.root)

    def test_renamed_source_rebuilds_identity(self):
        knowledge.Retriever(self.root,cache=self.cache)
        self.current.rename(self.current.with_name('renamed.md'))
        self.manifest.write_text(json.dumps({'documents':['systems/renamed.md']}))
        new=knowledge.Retriever(self.root,cache=self.cache)
        self.assertEqual(set(new.documents),{'systems/renamed.md'})
        self.assertNotIn('systems/current.md',self.cache.read_text())

    def test_empty_or_unmatched_query_explicitly_abstains(self):
        retriever=knowledge.Retriever(self.root)
        for query in ['', 'the and of', 'xylophonicallyzz']:
            result=retriever.query(query)
            self.assertTrue(result['abstention']);self.assertEqual(result['hits'],[])

    def test_one_linked_primary_record_is_followed_with_original_authority(self):
        self.write('docs/decisions/owner.md',document('# Owner preference\nOwner wants authored worlds.\n',authority='owner-confirmed-intent',status='Approved design',**{'document-kind':'decision'}))
        self.current.write_text(document('# Owner authoring overview\nOwner authoring worlds controls. [Primary record](../decisions/owner.md)\n'))
        self.manifest.write_text(json.dumps({'documents':['systems/current.md','decisions/owner.md']}))
        result=knowledge.Retriever(self.root).query('owner authoring worlds')
        owner=next(h for h in result['hits'] if h['path']=='decisions/owner.md')
        self.assertEqual(owner['authority'],'owner-confirmed-intent')
        self.assertEqual(owner['status'],'Approved design')

    def test_snapshot_fallback_and_manifest_select_same_real_corpus(self):
        # Existing frozen selection suite covers repository fallback; here the
        # adapter's stricter metadata and snapshot construction are exercised.
        first=knowledge.Retriever(self.root)
        self.manifest.unlink();second=knowledge.Retriever(self.root)
        self.assertEqual(first.chunks,second.chunks)
        self.assertNotEqual(first.identity['source_fingerprint'],second.identity['source_fingerprint'])


if __name__=='__main__':unittest.main()
