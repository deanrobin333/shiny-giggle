#!/bin/bash
# modified it to work with ubuntu 23.10
# if notion directory is not "/opt/Notion\ Enhanced", change line 43 and 333
function check_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root!" 1>&2
	echo "Enter route by typing 'sudo su' and then enter your root password" 1>&2
    exit 1
  fi
}

function help_menu() {
  echo "Usage: $0 [OPTION]"
  echo
  echo "By default (with no OPTION), the script will install the changes."
  echo
  echo "Options:"
  echo "  -u, --uninstall    Uninstall the changes and restore the original state."
  echo "  -h, --help         Display this help menu."
  echo
}

function install_changes() {
  # Check if asar is installed
  if ! command -v asar &>/dev/null; then
    echo "asar not found. Attempting to install..."

    if command -v apt &>/dev/null; then
      echo "Using snap to install asar..."
      sudo apt update && sudo snap install asar --classic
    elif command -v dnf &>/dev/null; then
      echo "Using dnf to install asar..."
      sudo dnf install -y asar
    elif command -v npm &>/dev/null; then
      echo "Using npm to install asar..."
      sudo npm install -g asar
    else
      echo "No suitable package manager found to install asar. Please install it manually."
      exit 1
    fi
  fi

  cd  /opt/Notion\ Enhanced/resources 

  asar extract app.asar app

  cp app.asar app.asar.bak

  cd app/renderer

  # Check if the modification has already been done
  if grep -q "require('notion-enhancer')('renderer/preload', exports, (js) => eval(js));" preload.js; then
    echo "Modification already done. Skipping..."
  else
    # Add a semicolon to the end of the specified line
    sed -i "s/require('notion-enhancer')('renderer\/preload', exports, (js) => eval(js))/&;/" preload.js
  fi

  # Check if the JavaScript function is already present
  if grep -q "__polyfill_2" preload.js; then
    echo "JavaScript function already added. Skipping..."
  else
    # Add the provided JavaScript function to the bottom of preload.js
    cat <<'EOL' >>preload.js

(function __polyfill_2() {
    function getClientHints(navigator) {
        let { userAgent } = navigator;
        let mobile, platform = '', platformVersion = '', architecture = '', bitness = '', model = '', uaFullVersion = '', fullVersionList = [];
        let platformInfo = userAgent;
        let found = false;
        let versionInfo = userAgent.replace(/\(([^)]+)\)?/g, (\$0, \$1) => {
            if (!found) {
                platformInfo = \$1;
                found = true;
            }
            return '';
        });
        let items = versionInfo.match(/(\S+)\/(\S+)/g);
        let webview = false;
        // detect mobile
        mobile = userAgent.indexOf('Mobile') !== -1;
        let m;
        let m2;
        // detect platform
        if ((m = /Windows NT (\d+(\.\d+)*)/.exec(platformInfo)) !== null) {
            platform = 'Windows';
            // see https://docs.microsoft.com/en-us/microsoft-edge/web-platform/how-to-detect-win11
            let nt2win = {
                '6.1': '0.1', // win-7
                '6.2': '0.2', // win-8
                '6.3': '0.3', // win-8.1
                '10.0': '10.0', // win-10
                '11.0': '13.0', // win-11
            };
            let ver = nt2win[m[1]];
            if (ver)
                platformVersion = padVersion(ver, 3);
            if ((m2 = /\b(WOW64|Win64|x64)\b/.exec(platformInfo)) !== null) {
                architecture = 'x86';
                bitness = '64';
            }
        } else if ((m = /Android (\d+(\.\d+)*)/.exec(platformInfo)) !== null) {
            platform = 'Android';
            platformVersion = padVersion(m[1]);
            if ((m2 = /Linux (\w+)/.exec(navigator.platform)) !== null) {
                if (m2[1]) {
                    m2 = parseArch(m2[1]);
                    architecture = m2[0];
                    bitness = m2[1];
                }
            }
        } else if ((m = /(iPhone|iPod touch); CPU iPhone OS (\d+(_\d+)*)/.exec(platformInfo)) !== null) {
            // see special notes at https://www.whatismybrowser.com/guides/the-latest-user-agent/safari
            platform = 'iOS';
            platformVersion = padVersion(m[2].replace(/_/g, '.'));
        } else if ((m = /(iPad); CPU OS (\d+(_\d+)*)/.exec(platformInfo)) !== null) {
            platform = 'iOS';
            platformVersion = padVersion(m[2].replace(/_/g, '.'));
        } else if ((m = /Macintosh; (Intel|\w+) Mac OS X (\d+(_\d+)*)/.exec(platformInfo)) !== null) {
            platform = 'macOS';
            platformVersion = padVersion(m2[2].replace(/_/g, '.'));
        } else if ((m = /Linux/.exec(platformInfo)) !== null) {
            platform = 'Linux';
            platformVersion = '';
            // TODO
        } else if ((m = /CrOS (\w+) (\d+(\.\d+)*)/.exec(platformInfo)) !== null) {
            platform = 'Chrome OS';
            platformVersion = padVersion(m[2]);
            m2 = parseArch(m[1]);
            architecture = m2[0];
            bitness = m2[1];
        }
        if (!platform) {
            platform = 'Unknown';
        }
        // detect fullVersionList / brands
        let notABrand = { brand: ' Not;A Brand', version: '99.0.0.0' };
        if ((m = /Chrome\/(\d+(\.\d+)*)/.exec(versionInfo)) !== null && navigator.vendor === 'Google Inc.') {
            fullVersionList.push({ brand: 'Chromium', version: padVersion(m[1], 4) });
            if ((m2 = /(Edge?)\/(\d+(\.\d+)*)/.exec(versionInfo)) !== null) {
                let identBrandMap = {
                    'Edge': 'Microsoft Edge',
                    'Edg': 'Microsoft Edge',
                };
                let brand = identBrandMap[m[1]];
                fullVersionList.push({ brand: brand, version: padVersion(m2[2], 4) });
            } else {
                fullVersionList.push({ brand: 'Google Chrome', version: padVersion(m[1], 4) });
            }
            if (/\bwv\b/.exec(platformInfo)) {
                webview = true;
            }
        } else if ((m = /AppleWebKit\/(\d+(\.\d+)*)/.exec(versionInfo)) !== null && navigator.vendor === 'Apple Computer, Inc.') {
            fullVersionList.push({ brand: 'WebKit', version: padVersion(m[1]) });
            if (platform === 'iOS' && (m2 = /(CriOS|EdgiOS|FxiOS|Version)\/(\d+(\.\d+)*)/.exec(versionInfo)) != null) {
                let identBrandMap = { // no
                    'CriOS': 'Google Chrome',
                    'EdgiOS': 'Microsoft Edge',
                    'FxiOS': 'Mozilla Firefox',
                    'Version': 'Apple Safari',
                };
                let brand = identBrandMap[m2[1]];
                fullVersionList.push({ brand, version: padVersion(m2[2]) });
                if (items.findIndex((s) => s.startsWith('Safari/')) === -1) {
                    webview = true;
                }
            }
        } else if ((m = /Firefox\/(\d+(\.\d+)*)/.exec(versionInfo)) !== null) {
            fullVersionList.push({ brand: 'Firefox', version: padVersion(m[1]) });
        } else if ((m = /(MSIE |rv:)(\d+\.\d+)/.exec(platformInfo)) !== null) {
            fullVersionList.push({ brand: 'Internet Explorer', version: padVersion(m[2]) });
        } else {
            fullVersionList.push(notABrand);
        }
        uaFullVersion = fullVersionList.length > 0 ? fullVersionList[fullVersionList.length - 1] : '';
        let brands = fullVersionList.map((b) => {
            let pos = b.version.indexOf('.');
            let version = pos === -1 ? b.version : b.version.slice(0, pos);
            return { brand: b.brand, version };
        });
        // TODO detect architecture, bitness and model
        return {
            mobile,
            platform,
            brands,
            platformVersion,
            architecture,
            bitness,
            model,
            uaFullVersion,
            fullVersionList,
            webview
        };
    }

    function parseArch(arch) {
        switch (arch) {
            case 'x86_64':
            case 'x64':
                return ['x86', '64'];
            case 'x86_32':
            case 'x86':
                return ['x86', ''];
            case 'armv6l':
            case 'armv7l':
            case 'armv8l':
                return [arch, ''];
            case 'aarch64':
                return ['arm', '64'];
            default:
                return ['', ''];
        }
    }
    function padVersion(ver, minSegs = 3) {
        let parts = ver.split('.');
        let len = parts.length;
        if (len < minSegs) {
            for (let i = 0, lenToPad = minSegs - len; i < lenToPad; i += 1) {
                parts.push('0');
            }
            return parts.join('.');
        }
        return ver;
    }

    class NavigatorUAData {
        constructor() {
            this._ch = getClientHints(navigator);
            Object.defineProperties(this, {
                _ch: { enumerable: false },
            });
        }
        get mobile() {
            return this._ch.mobile;
        }
        get platform() {
            return this._ch.platform;
        }
        get brands() {
            return this._ch.brands;
        }
        getHighEntropyValues(hints) {
            return new Promise((resolve, reject) => {
                if (!Array.isArray(hints)) {
                    throw new TypeError('argument hints is not an array');
                }
                let hintSet = new Set(hints);
                let data = this._ch;
                let obj = {
                    mobile: data.mobile,
                    platform: data.platform,
                    brands: data.brands,
                };
                if (hintSet.has('architecture'))
                    obj.architecture = data.architecture;
                if (hintSet.has('bitness'))
                    obj.bitness = data.bitness;
                if (hintSet.has('model'))
                    obj.model = data.model;
                if (hintSet.has('platformVersion'))
                    obj.platformVersion = data.platformVersion;
                if (hintSet.has('uaFullVersion'))
                    obj.uaFullVersion = data.uaFullVersion;
                if (hintSet.has('fullVersionList'))
                    obj.fullVersionList = data.fullVersionList;
                resolve(obj);
            });
        }
        toJSON() {
            let data = this._ch;
            return {
                mobile: data.mobile,
                brands: data.brands,
            };
        }
    }
    Object.defineProperty(NavigatorUAData.prototype, Symbol.toStringTag, {
        enumerable: false,
        configurable: true,
        writable: false,
        value: 'NavigatorUAData'
    });

    function ponyfill() {
        return new NavigatorUAData(navigator);
    }
    function polyfill() {
        console.log("Try polyfill .  .  .");

        // When Notion , no need https?
        const ____use_https = false;

        if (
            (!____use_https || location.protocol === 'https:')
            && !navigator.userAgentData
        ) {
            console.log("Here,begin userAgentData polyfill .  .  .")
            let userAgentData = new NavigatorUAData(navigator);
            Object.defineProperty(Navigator.prototype, 'userAgentData', {
                enumerable: true,
                configurable: true,
                get: function getUseAgentData() {
                    return userAgentData;
                }
            });
            Object.defineProperty(window, 'NavigatorUAData', {
                enumerable: false,
                configurable: true,
                writable: true,
                value: NavigatorUAData
            });
            return true;
        }
        return false;
    }


    // Simple Apply this code.
    ponyfill();
    polyfill();
})();
EOL
  fi

  # Navigate back
  cd ../..

  # Repack the asar archive
  asar pack ./app app.asar
}

function uninstall_changes() {
  cd  /opt/Notion\ Enhanced/resources 

  if [ -f "app.asar.bak" ]; then
    echo "Restoring original app.asar from backup..."
    mv app.asar.bak app.asar
  else
    echo "Backup not found! Cannot restore original state."
    exit 1
  fi

  if [ -d "app" ]; then
    echo "Removing extracted directory..."
    rm -rf app
  fi

  echo "Uninstall complete!"
}

if [[ "$1" == "-u" || "$1" == "--uninstall" ]]; then
  check_root
  uninstall_changes
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
  help_menu
else
  check_root
  install_changes
fi
