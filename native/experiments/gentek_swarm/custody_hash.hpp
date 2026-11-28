#pragma once

#include <array>
#include <atomic>
#include <bit>
#include <cstdint>
#include <ostream>
#include <stdexcept>
#include <streambuf>

namespace cybersand::gentek_swarm::assembly004 {
// Internal streaming SHA-256. The digest is useful only while bound to the
// private native run authority; a public digest can never mint that authority.
using CustodyDigest = std::array<std::uint32_t,8>;
class CustodyHashBuffer final : public std::streambuf {
    std::array<std::uint8_t,64> block_{};
    CustodyDigest state_{0x6a09e667U,0xbb67ae85U,0x3c6ef372U,0xa54ff53aU,
                         0x510e527fU,0x9b05688cU,0x1f83d9abU,0x5be0cd19U};
    std::size_t size_{};
    std::uint64_t bytes_{}, blocks_{};
    std::uint64_t& charged_;
    std::uint64_t ceiling_;
    const std::atomic_bool* cancel_;
    bool finished_ = false;
    void compress() {
        // SWARM006 metadata accounting v1: four work units per 64-byte
        // canonical encoding/SHA block, including padding; charged BEFORE the
        // compression. Both minting and every verification are charged.
        constexpr std::array<std::uint32_t,64> k{
            0x428a2f98U,0x71374491U,0xb5c0fbcfU,0xe9b5dba5U,0x3956c25bU,0x59f111f1U,0x923f82a4U,0xab1c5ed5U,
            0xd807aa98U,0x12835b01U,0x243185beU,0x550c7dc3U,0x72be5d74U,0x80deb1feU,0x9bdc06a7U,0xc19bf174U,
            0xe49b69c1U,0xefbe4786U,0x0fc19dc6U,0x240ca1ccU,0x2de92c6fU,0x4a7484aaU,0x5cb0a9dcU,0x76f988daU,
            0x983e5152U,0xa831c66dU,0xb00327c8U,0xbf597fc7U,0xc6e00bf3U,0xd5a79147U,0x06ca6351U,0x14292967U,
            0x27b70a85U,0x2e1b2138U,0x4d2c6dfcU,0x53380d13U,0x650a7354U,0x766a0abbU,0x81c2c92eU,0x92722c85U,
            0xa2bfe8a1U,0xa81a664bU,0xc24b8b70U,0xc76c51a3U,0xd192e819U,0xd6990624U,0xf40e3585U,0x106aa070U,
            0x19a4c116U,0x1e376c08U,0x2748774cU,0x34b0bcb5U,0x391c0cb3U,0x4ed8aa4aU,0x5b9cca4fU,0x682e6ff3U,
            0x748f82eeU,0x78a5636fU,0x84c87814U,0x8cc70208U,0x90befffaU,0xa4506cebU,0xbef9a3f7U,0xc67178f2U};
        std::array<std::uint32_t,64> w{};
        for(unsigned i=0;i<16;++i)for(unsigned j=0;j<4;++j)w[i]=(w[i]<<8U)|block_[i*4+j];
        for(unsigned i=16;i<64;++i){const auto x=w[i-15],y=w[i-2];
            w[i]=w[i-16]+(std::rotr(x,7)^std::rotr(x,18)^(x>>3U))+w[i-7]+(std::rotr(y,17)^std::rotr(y,19)^(y>>10U));}
        auto a=state_[0],b=state_[1],c=state_[2],d=state_[3],e=state_[4],f=state_[5],g=state_[6],h=state_[7];
        for(unsigned i=0;i<64;++i){
            const auto t1=h+(std::rotr(e,6)^std::rotr(e,11)^std::rotr(e,25))+((e&f)^((~e)&g))+k[i]+w[i];
            const auto t2=(std::rotr(a,2)^std::rotr(a,13)^std::rotr(a,22))+((a&b)^(a&c)^(b&c));
            h=g;g=f;f=e;e=d+t1;d=c;c=b;b=a;a=t1+t2;
        }
        state_[0]+=a;state_[1]+=b;state_[2]+=c;state_[3]+=d;
        state_[4]+=e;state_[5]+=f;state_[6]+=g;state_[7]+=h;size_=0;
    }
    void put(std::uint8_t value){
        if(!size_){
            if(cancel_&&cancel_->load(std::memory_order_relaxed))throw std::runtime_error("native custody cancellation");
            if(charged_>ceiling_||ceiling_-charged_<4)throw std::length_error("native custody work allowance");
            charged_+=4;++blocks_;
        }
        block_[size_++]=value;if(size_==64)compress();
    }
protected:
    int_type overflow(int_type value) override {
        if(traits_type::eq_int_type(value,traits_type::eof()))return traits_type::not_eof(value);
        if(finished_||bytes_>=64U*1024U*1024U)throw std::length_error("bounded native custody encoding");
        ++bytes_;put(static_cast<std::uint8_t>(traits_type::to_char_type(value)));return value;
    }
    std::streamsize xsputn(const char* data,std::streamsize length) override {
        for(std::streamsize i=0;i<length;++i)overflow(traits_type::to_int_type(data[i]));
        return length;
    }
public:
    explicit CustodyHashBuffer(std::uint64_t& charged,std::uint64_t ceiling,const std::atomic_bool* cancel=nullptr):charged_(charged),ceiling_(ceiling),cancel_(cancel){}
    CustodyDigest finish(){
        if(finished_)throw std::logic_error("native custody digest already finalized");
        const auto bits=bytes_*8;put(0x80);while(size_!=56)put(0);
        for(int shift=56;shift>=0;shift-=8)put(static_cast<std::uint8_t>(bits>>static_cast<unsigned>(shift)));
        finished_=true;return state_;
    }
    std::uint64_t bytes()const{return bytes_;}
    std::uint64_t blocks()const{return blocks_;}
};
} // namespace cybersand::gentek_swarm::assembly004
