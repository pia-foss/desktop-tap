# Building the TAP Adapter for Private Internet Access

The steps required to build the TAP adapter driver for the Private Internet Access desktop client have been encapsulated into a custom wrapper build script.

**Note:** Private Internet Access does not require any side components such as `tapinstall.exe`. If you need to acquire these, consult the original [tap-windows6](https://github.com/OpenVPN/tap-windows6) repository.

## Prerequisites

- Python 2.7 (needs to be in your `PATH`)
- Microsoft Windows 10 EWDK (Enterprise Windows Driver Kit)
- Windows code signing EV certificate

## Digitally signing the driver

In order to install drivers on modern versions Windows they need to be digitally signed with an EV (Extended Validation) certificate. To maximize compatibility with older Windows versions, the build script can double-sign the driver with both a SHA1 and a SHA256 certificate.

Additionally, for Windows 10 a properly EV-signed driver package can be submitted to Microsoft to have its signature replaced with a Microsoft certificate. This will let the driver be installed automatically without requiring an additional user authorization prompt.

**Note:** The build script digitally signs the drivers as a post-build step; standard tap-windows6 build outputs such as tap6.tar.gz will contain the still-unsigned versions.

## Usage

The build script is configurable in a few ways using environment variables (for convenience when using CI builders):

- If you installed the EWDK in a subfolder of `C:\EWDK` the build script will pick it up automatically. Otherwise, set the `EWDK` environment variable to point to the EWDK directory.

- Specify the SHA256 code signing certificate thumbprint with `PIA_TAP_SHA256_CERT`. To double-sign, also specify the SHA1 code signing certificate with `PIA_TAP_SHA1_CERT`.

- If you are using a certificate from somewhere other than DigiCert, specify the CA certificate with `PIA_TAP_CROSSCERT` and the timestamp server URL with `PIA_TAP_TIMESTAMP`.

After configuring the environment, merely execute the build script:

```shell
> build-pia.bat
```

**Note:** You may run into a certificate error if this is the first time you are building with the EWDK, if it is unable to generate a temporary test certificate while building the drivers. To resolve this, run the build script as administrator the first time (not necessary on subsequent builds).

After building, the drivers are placed in `dist/i386` and `dist/amd64`, and signed CABs for Microsoft submission are placed in `dist`.
