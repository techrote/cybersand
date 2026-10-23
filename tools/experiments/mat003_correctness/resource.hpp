#pragma once
#include <cstdlib>
#include <fstream>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <psapi.h>
#else
#include <sys/resource.h>
#endif
struct ResourceReceipt {
    ~ResourceReceipt(){
        const char* path=std::getenv("MAT003_RESOURCE_RECEIPT");if(!path)return;
        unsigned long long peak=0;
#ifdef _WIN32
        PROCESS_MEMORY_COUNTERS counters{};counters.cb=sizeof(counters);
        if(GetProcessMemoryInfo(GetCurrentProcess(),&counters,sizeof(counters)))peak=counters.PeakWorkingSetSize;
#else
        struct rusage usage{};if(getrusage(RUSAGE_SELF,&usage)==0)peak=static_cast<unsigned long long>(usage.ru_maxrss)*1024;
#endif
        std::ofstream out(path);out<<peak<<'\n';
    }
};
