#!/bin/sh
# https://gist.github.com/Leo-PL/1ee48d132bc7a7ccd4657ea1ed7badd8#file-mobile-usb-network-setup-L11

CONFIGFS=/sys/kernel/config/usb_gadget/g1
USB_VENDORID="0x1D6B"  # Linux Foundation
USB_PRODUCTID="0x0104" # Multifunction composite gadget
USB_MANUF="Debian"
USB_PRODUCT="Mobile USB Gadget"
USB_SERIAL=$(sha256sum < /etc/machine-id | cut -d' ' -f1)
USB_ATTRIBUTES="0x80" # Bus-powered
USB_MAX_POWER="500" # mA
USB_DEVICE_CLASS="0xEF"
USB_DEVICE_SUBCLASS="0x02"
USB_DEVICE_PROTOCOL="0x01"
MAC="$(echo ${USB_SERIAL} | cut -b -10 | sed 's/..\B/&:/g')"
HOST_MAC="12${MAC}"
DEVICE_MAC="02${MAC}"
MS_VENDOR_CODE="0xcd" # Microsoft
MS_QW_SIGN="MSFT100" # also Microsoft (if you couldn't tell)
MS_COMPAT_ID="RNDIS" # matches Windows RNDIS Drivers
MS_SUBCOMPAT_ID="5162001" # matches Windows RNDIS 6.0 Driver

setup() {
    # Don't do anything if the USB gadget already exists
    [ -d $CONFIGFS ] && exit 0

    # Required to make a composite gadget
    modprobe libcomposite

    # Create all required directories
    echo "Creating the USB gadget..."
    mkdir -p $CONFIGFS
    mkdir -p $CONFIGFS/strings/0x409
    mkdir -p $CONFIGFS/configs/c.1
    mkdir -p $CONFIGFS/configs/c.1/strings/0x409
    mkdir -p $CONFIGFS/configs/c.2
    mkdir -p $CONFIGFS/configs/c.2/strings/0x409

    # Setup IDs and strings
    echo "Setting up gadget strings..."
    echo $USB_VENDORID > $CONFIGFS/idVendor
    echo $USB_PRODUCTID > $CONFIGFS/idProduct
    echo $USB_DEVICE_CLASS > $CONFIGFS/bDeviceClass
    echo $USB_DEVICE_SUBCLASS > $CONFIGFS/bDeviceSubClass
    echo $USB_DEVICE_PROTOCOL > $CONFIGFS/bDeviceProtocol
    echo $USB_MANUF > $CONFIGFS/strings/0x409/manufacturer
    echo $USB_PRODUCT > $CONFIGFS/strings/0x409/product
    echo $USB_SERIAL > $CONFIGFS/strings/0x409/serialnumber

    # On Windows 7 and later, the RNDIS 5.1 driver would be used by default,
    # but it does not work very well. The RNDIS 6.0 driver works better. In
    # order to get this driver to load automatically, we have to use a
    # Microsoft-specific extension of USB.

    echo "1" > $CONFIGFS/os_desc/use
    echo "${MS_VENDOR_CODE}" > $CONFIGFS/os_desc/b_vendor_code
    echo "${MS_QW_SIGN}" > $CONFIGFS/os_desc/qw_sign

    # Create ACM (serial) function
    echo "Adding ACM function..."
    mkdir $CONFIGFS/functions/acm.GS0

    # Create rndis (ethernet) function
    echo "Adding RNDIS function..."
    mkdir $CONFIGFS/functions/rndis.usb0
    echo $HOST_MAC > $CONFIGFS/functions/rndis.usb0/host_addr
    echo $DEVICE_MAC > $CONFIGFS/functions/rndis.usb0/dev_addr
    echo ef > $CONFIGFS/functions/rndis.usb0/class
    echo 04 > $CONFIGFS/functions/rndis.usb0/subclass
    echo 01 > $CONFIGFS/functions/rndis.usb0/protocol
    echo "${MS_COMPAT_ID}" > $CONFIGFS/functions/rndis.usb0/os_desc/interface.rndis/compatible_id
    echo "${MS_SUBCOMPAT_ID}" > $CONFIGFS/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id

    # Create ECM (ethernet) function
    echo "Adding RNDIS function..."
    mkdir $CONFIGFS/functions/ecm.usb1
    echo $HOST_MAC > $CONFIGFS/functions/ecm.usb1/host_addr
    echo $DEVICE_MAC > $CONFIGFS/functions/ecm.usb1/dev_addr

    # Create configuration 1 (RNDIS)
    echo "Creating gadget configuration..."
    echo "RNDIS" > $CONFIGFS/configs/c.1/strings/0x409/configuration
    echo "$USB_ATTRIBUTES" > $CONFIGFS/configs/c.2/bmAttributes
    echo "$USB_MAX_POWER" > $CONFIGFS/configs/c.2/MaxPower
    ln -s $CONFIGFS/configs/c.1 $CONFIGFS/os_desc
    # It is required for RNDIS to go first for Windows to detect this properly
    ln -s $CONFIGFS/functions/rndis.usb0 $CONFIGFS/configs/c.1
    ln -s $CONFIGFS/functions/acm.GS0 $CONFIGFS/configs/c.1

    # Create configuration 2 (CDC)
    echo "Creating gadget configuration..."
    echo "CDC" > $CONFIGFS/configs/c.2/strings/0x409/configuration
    # It is required for ECM to go first, so Linux and Mac switch to this configuration
    ln -s $CONFIGFS/functions/ecm.usb1 $CONFIGFS/configs/c.2
    ln -s $CONFIGFS/functions/acm.GS0 $CONFIGFS/configs/c.2

    echo "Enabling the USB gadget..."
    UDC=`ls /sys/class/udc`
    echo "$UDC" > $CONFIGFS/UDC
}

reset() {
    echo "Removing the USB gadget..."

    # Remove USB gadget
    if [ -d $CONFIGFS ]; then
        echo "Removing gadget configuration..."
        unlink $CONFIGFS/os_desc/c.1
        rm $CONFIGFS/configs/c.2/acm.GS0
        rm $CONFIGFS/configs/c.2/ecm.usb1
        rm $CONFIGFS/configs/c.1/acm.GS0
        rm $CONFIGFS/configs/c.1/rndis.usb0
        rmdir $CONFIGFS/configs/c.2/strings/0x409/
        rmdir $CONFIGFS/configs/c.2/
        rmdir $CONFIGFS/configs/c.1/strings/0x409/
        rmdir $CONFIGFS/configs/c.1/
        rmdir $CONFIGFS/functions/ecm.usb1
        rmdir $CONFIGFS/functions/rndis.usb0
        rmdir $CONFIGFS/functions/acm.GS0
        rmdir $CONFIGFS/strings/0x409/
        rmdir $CONFIGFS
    fi
}

case "$1" in
    reset) reset ;;
    setup) setup ;;
    *) echo "Usage: $0 {setup|reset}" ;;
esac