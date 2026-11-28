#include "custody_hash.hpp"
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

using namespace cybersand::gentek_swarm::assembly004;
namespace {
unsigned checks=0;
void check(bool value,const char* why){++checks;if(!value)throw std::runtime_error(why);}
std::string hash(const std::string& input,bool singles=false){
    std::uint64_t work=0;CustodyHashBuffer buffer(work,1'000'000);std::ostream stream(&buffer);
    stream.exceptions(std::ios::badbit|std::ios::failbit);
    if(singles)for(auto byte:input)stream.put(byte);else stream<<input;
    const auto digest=buffer.finish();std::ostringstream text;text<<std::hex<<std::setfill('0');
    for(auto word:digest)text<<std::setw(8)<<word;
    check(work==4*((input.size()+9+63)/64),"exact hash block debit");return text.str();
}
}
int main(){try{
    check(hash("")=="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","SHA256 empty");
    check(hash("abc")=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad","SHA256 abc");
    const std::string multi="abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
    check(hash(multi)=="248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1","SHA256 multiblock");
    check(hash(multi,true)==hash(multi),"incremental digest equivalence");
    check(hash(std::string(1'000'000,'a'))=="cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0","SHA256 million a");
    std::uint64_t work=0;CustodyHashBuffer bounded(work,4);std::ostream stream(&bounded);stream.exceptions(std::ios::badbit|std::ios::failbit);
    bool exhausted=false;try{stream<<std::string(65,'x');}catch(const std::exception&){exhausted=true;}
    check(exhausted&&work==4&&bounded.blocks()==1,"failed hash retains first debit and stops before next block");
    std::atomic_bool cancel=true;work=0;CustodyHashBuffer stopped(work,100,&cancel);std::ostream stopped_stream(&stopped);stopped_stream.exceptions(std::ios::badbit|std::ios::failbit);
    bool cancelled=false;try{stopped_stream<<"x";}catch(const std::exception&){cancelled=true;}
    check(cancelled&&work==0,"cancel before compression");
    std::cout<<"custody hash: "<<checks<<" assertions PASS\n";
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
