#include "resource.hpp"
// Isolated raw storage schedule; no timing code.
#include "maps.hpp"
#include "schedule.hpp"
#include <iostream>
#include <iomanip>
#include <string>
using Cell=mat003_correctness::Cell<MAT003_CAPACITY,MAT003_EPOCH_BITS>;
void bytes(const Cell& c){for(auto b:c.canonical())std::cout<<std::hex<<std::setw(2)<<std::setfill('0')<<unsigned(b);std::cout<<std::dec;}
int main(int argc,char** argv){
    ResourceReceipt resource;
    if(argc!=2||std::string(argv[1])!="--correctness-only")return 2;
    std::array<Cell,1024> cells{};
    for(unsigned i=0;i<65536;++i){auto a=action(i);auto& left=cells[a.left];auto& right=cells[a.right];
        std::cout<<i<<' '<<a.op<<' '<<a.left<<' '<<a.right<<' '<<a.field<<' '<<a.negative<<' '<<a.value<<' ';bytes(left);std::cout<<' ';bytes(right);std::cout<<' ';
        bool ok=true;
        if(a.negative)ok=left.checked_signed(a.field,-1);
        else if(a.op==6||a.op==7)ok=left.checked_write(left.read(),a.op==6?2:1,a.op!=7);
        else {auto r=left.read();
            if(a.op==0){switch(a.field){case 0:r.material=a.value;break;case 1:r.a=a.value;break;case 2:r.b=a.value;break;case 3:r.epoch=a.value;break;case 4:r.r=a.value;break;}ok=left.write_raw(r);}
            if(a.op==1)left=right;
            if(a.op==2)std::swap(left,right);
            if(a.op==3)left=Cell{};
            if(a.op==4)left.clear_epoch();
            if(a.op==5){r.u=a.value;ok=left.write_raw(r);}
        }
        std::cout<<ok<<' ';bytes(left);std::cout<<' ';bytes(right);std::cout<<'\n';
    }
    return std::cout?0:3;
}
