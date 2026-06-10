// RegionSpoof.kext — overrides IOPlatformExpertDevice region props for MobileGestalt.
#include <IOKit/IOService.h>
#include <IOKit/IOLib.h>
#include <libkern/c++/OSData.h>
class com_local_RegionSpoof : public IOService {
    OSDeclareDefaultStructors(com_local_RegionSpoof)
public:
    virtual bool start(IOService *provider) override;
    virtual void stop(IOService *provider) override;
};
OSDefineMetaClassAndStructors(com_local_RegionSpoof, IOService)
bool com_local_RegionSpoof::start(IOService *provider){
    if (!IOService::start(provider)) return false;
    unsigned char region[32]; for (int i=0;i<32;i++) region[i]=0;
    region[0]='L';region[1]='L';region[2]='/';region[3]='A';
    OSData *rd=OSData::withBytes(region,sizeof(region));
    if(rd){provider->setProperty("region-info",rd);rd->release();}
    OSData *cd=OSData::withBytes("USA",3);
    if(cd){provider->setProperty("country-of-origin",cd);cd->release();}
    IOLog("RegionSpoof: region-info=LL/A set on %s\n", provider?provider->getName():"?");
    registerService(); return true;
}
void com_local_RegionSpoof::stop(IOService *provider){ IOService::stop(provider); }
