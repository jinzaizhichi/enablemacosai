Built kext lives at /Library/Extensions/RegionSpoof.kext (loads at boot via
/Library/LaunchDaemons/com.local.regionkext.plist). Effect: IORegistry
region-info CH/A -> LL/A, so MobileGestalt RegionCode = "LL" for every process.
Requires: SIP disabled + Permissive Security + 3rd-party kexts enabled (already set).
Uninstall: bootout com.local.regionkext + com.local.RegionSpoof kext, rm both,
remove /Library/Extensions/RegionSpoof.kext, reboot.
