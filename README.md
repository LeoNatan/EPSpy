# EPSpy

Records supported [EndpointSecurity.framework](https://developer.apple.com/documentation/endpointsecurity) events into a JSON file.

<p align="center"><img src="./Screenshot.png"/></p>

### Installing

Release binaries are signed with adhoc certificate and have the `com.apple.developer.endpoint-security.client` entitlement, so it is required that `SIP` and/or `AMFI` [be disabled](https://gist.github.com/LeoNatan/b1cf77e1a0df2558f02631656e596408) to run. It is recommended to run this tool in a VM.

Before installing, make sure **Homebrew** is installed: https://brew.sh

To install EPSpy or upgrade:

```shell
brew update
curl --create-dirs -O --output-dir /tmp https://raw.githubusercontent.com/LeoNatan/EPSpy/refs/heads/master/epspy.rb
brew install --force --no-quarantine --cask /tmp/epspy.rb
```

To uninstall:

```shell
curl --create-dirs -O --output-dir /tmp https://raw.githubusercontent.com/LeoNatan/EPSpy/refs/heads/master/epspy.rb
brew uninstall --cask /tmp/epspy.rb
```

### Running

On first run record, the system will ask you to enable an extension. Enable it right away in the notification:

<p align="center"><img width=393 src="./Notification.png"/></p>

 or in **Settings**, under **Login Items & Extensions**:

<p align="center"><img width=827 src="./Settings.png"/></p>

### Troubleshooting

- The following error indicates that the login iten has not been enabled.

<p align="center"><img width=372 src="./Error.png"/></p>

- If you click on the record button and nothing happens, including no error, it means you are trying to record on a machine that is SIP enabled. Disable SIP and try again.
