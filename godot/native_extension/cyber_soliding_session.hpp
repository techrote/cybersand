#pragma once
#include "cybersand/soliding_session.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/rect2i.hpp>
namespace godot {
class CyberSolidingSession : public RefCounted {
    GDCLASS(CyberSolidingSession,RefCounted)
    std::unique_ptr<cybersand::soliding::Session> session_;
    static bool on_main(){const auto* os=OS::get_singleton();return os&&os->get_thread_caller_id()==os->get_main_thread_id();}
    bool ready()const{return on_main()&&session_!=nullptr;}
    static cybersand::soliding::Token decode(const PackedInt64Array& t){cybersand::soliding::Token v{};if(t.size()==7)for(int i=0;i<7;++i)v[i]=static_cast<std::uint64_t>(t[i]);return v;}
    static cybersand::soliding::Motion motion(const PackedFloat64Array& v){if(v.size()!=6)return {NAN,NAN,NAN,NAN,NAN,NAN};return {v[0],v[1],v[2],v[3],v[4],v[5]};}
protected:
    static void _bind_methods(){
#define BIND(name) ClassDB::bind_method(D_METHOD(#name),&CyberSolidingSession::name)
        BIND(configure);BIND(tick);BIND(status);BIND(token);BIND(prepare_promotion);BIND(prepare_reversal);
        BIND(acknowledge);BIND(commit);BIND(finalize);BIND(cancel);BIND(occupancy);BIND(observe_motion);BIND(set_excluded);BIND(edit);BIND(persistence_allowed);BIND(quarantine);
#undef BIND
    }
public:
    bool configure(int width,int height,int workers){if(!on_main()||session_)return false;try{session_=std::make_unique<cybersand::soliding::Session>(static_cast<unsigned>(width),static_cast<unsigned>(height),static_cast<unsigned>(workers));return true;}catch(...){return false;}}
    bool tick(){return ready()&&session_->tick();}
    bool prepare_promotion(){return ready()&&session_->prepare_promotion();}
    bool prepare_reversal(const PackedFloat64Array& m){return ready()&&session_->prepare_reversal(motion(m));}
    bool acknowledge(const PackedInt64Array& t){return ready()&&session_->acknowledge(decode(t));}
    bool commit(const PackedInt64Array& t){return ready()&&session_->commit(decode(t));}
    bool finalize(const PackedInt64Array& t,bool verified){return ready()&&session_->finalize(decode(t),verified);}
    bool cancel(const PackedInt64Array& t){return ready()&&session_->cancel(decode(t));}
    bool set_excluded(bool excluded){return ready()&&session_->set_excluded(excluded);}
    bool observe_motion(const PackedFloat64Array& m,int64_t serial){return ready()&&serial>0&&session_->observe_motion(motion(m),static_cast<std::uint64_t>(serial));}
    bool persistence_allowed(){return ready()&&session_->persistence_allowed();}
    void quarantine(){if(ready())session_->quarantine();}
    // Fixture edits exist only in the native test harness before topology setup.
    bool edit(int,int,int,int){return false;}
    PackedInt64Array token(){PackedInt64Array result;if(ready())for(auto v:session_->token())result.append(static_cast<int64_t>(v));return result;}
    Dictionary occupancy(const PackedFloat64Array& m){Dictionary d;if(!ready())return d;const auto r=session_->occupancy(motion(m));d["complete"]=r.complete;d["required"]=r.required;d["written"]=r.written;d["conflicts"]=r.conflicts;return d;}
    Dictionary status(){Dictionary d;if(!ready())return d;const auto s=session_->status();d["phase"]=static_cast<int>(s.phase);d["members"]=s.members;d["cell_members"]=s.cell_members;d["slot_members"]=s.slot_members;d["rest"]=s.rest;d["motion_rest"]=s.motion_rest;d["payload_hash"]=static_cast<int64_t>(s.payload_hash);d["failed"]=s.failed;d["excluded"]=s.excluded;d["snap_x"]=s.snap_x;d["snap_y"]=s.snap_y;d["snap_angle"]=s.snap_angle;d["speed_bound"]=s.speed_bound;d["discarded_energy"]=s.discarded_energy;d["rectangle"]=Rect2i(static_cast<int>(s.rectangle.x),static_cast<int>(s.rectangle.y),static_cast<int>(s.rectangle.width),static_cast<int>(s.rectangle.height));d["session_bytes"]=static_cast<int64_t>(sizeof(cybersand::soliding::Session));return d;}
};
}
