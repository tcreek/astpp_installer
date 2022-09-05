# astpp_installer
This installation script is partly based on the iNetrix Technologies Pvt. Ltd. installtion script for installing ASTPP.
#
This script will only install version 5 of ASTPP, and for using only  
Debian 10 (Debian 11 not working now).

The purpose of this script is for multiple reasons compared to the one providedby iNetrix:

 1) Compiles FreeSwitch from source instead of using the SignalWire repo 
    which requires a SignalWire account with a token attached to that account

 2) Uses MariaDB from the Debian repo instead of MySQL from their repo.
    This has caused issues in the past

 3) Does not use RemiRepo for PHP 7.3+. iNetrix for unknown reasons uses the RemiRepo  

 4) No longer support of CentOS 7/8 as those are End of Life
    CentOS Stream is now the default distro, and not stable for production
    May consider Rocky Linux 8 (CentOS 8 fork) in the future

 5) Option to install Postfix instead of sendmail which provides better logging

 6) No telemetry sent



To excute installer: 
chmod +x astpp_v5_install.sh
./astpp_v5_install.sh



