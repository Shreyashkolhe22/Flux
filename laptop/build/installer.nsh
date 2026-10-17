; Extra steps for the Flux installer (runs elevated because the install is per-machine).
!macro customInstall
  ; Let the phone reach Flux on port 3000, local network only, any network profile
  ; (a phone hotspot is often classed as "Public" by Windows).
  nsExec::Exec 'netsh advfirewall firewall delete rule name="Flux"'
  nsExec::Exec 'netsh advfirewall firewall add rule name="Flux" dir=in action=allow protocol=TCP localport=3000 profile=any remoteip=localsubnet'
!macroend

!macro customUnInstall
  nsExec::Exec 'netsh advfirewall firewall delete rule name="Flux"'
!macroend
