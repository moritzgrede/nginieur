# nginieur
nginieur /ɛndʒɪnjœʁ/ is dynamic modular nginx configuration generator. Supplying a template, you can generate a finished nginx configuration.

## ⭐ Features
The templating engine supports the following options:
- Inclusion of files ``include <file>``

All options are recursively evaluated. So for the ``include`` option, all included files also get parsed by the templating engine. This differs from the nginx implementation of the [``include`` directive](https://nginx.org/en/docs/ngx_core_module.html#include).

### Planned
- Add option to reload the configuration after creation (``nginx -s reload``)
- Templating function to replace a variable with a given value

## ✒️ Syntax
```
New-NginxConfiguration.ps1
    [-WorkingDirectory <String>]
    [-NginxConfigurationFileName <String>]
    [-NginxConfigurationDestinationFileName <String>]
    [-Depth <Int32>]
    [-NoMetadata]
    [<CommonParameters>]
```
```
New-NginxConfiguration.ps1
    [-NginxConfigurationFile <String>]
    [-NginxConfigurationDestinationFile <String>]
    [-Depth <Int32>]
    [-NoMetadata]
    [<CommonParameters>]
```
You may either define a ``WorkingDirectory`` which will expect your template and configuration to be relative to the working directory (you can specify their names with ``NginxConfigurationFileName`` and ``NginxConfigurationDestinationFileName`` respectively) or you enter the paths to the template and configuration directly (using ``NginxConfigurationFile`` and ``NginxConfigurationDestinationFile`` respectively).

Paths interpreted by the ``include`` option are always relative to the ``WorkingDirectory`` (which will either be the value you specified or the current working directory).

## ⚡ Examples
### Generate a configuration
Assuming you are in a folder with an existing ``nginx.template`` you may just run
```
pwsh -File New-NginxConfiguration.ps1
```

### Example configuration
``nginx.template``:
```
http {
	# (Security) Defaults
	server_tokens off;
	add_header X-XSS-Protection "1; mode=block";
	add_header X-Frame-Options "SAMEORIGIN";
	add_header Content-Security-Policy "default-src 'self'; script-src 'self'";

	# Endpoints
	include server.conf;
}
```
``server.conf``:
```
server {
	server_name example.com;

	include ssl-default.conf;
	include ssl-example.com.conf;

	location / {
		proxy_pass "http://app:8000;
	}
}
```
``ssl-default.conf``:
```
listen [::]:443 ssl;
http2 on;
add_header Strict-Transport-Security "max-age=31536000; includeSubdomains" always;
ssl_protocols TLSv1.2 TLSv1.3;
```
``ssl-example.com.conf``:
```
ssl_certificate /foo/bar/com.example.fullchain;
ssl_certificate_key /foo/bar/com.example.privkey;
```

## 📄 Arguments
### -WorkingDirectory
Working directory to which the template and configuration files are relative to. Is also used to determine the location of files specified by the ``include`` option.

| | |
| -- | -- |
| Type: | ``String`` |
| Default value: | Current working directory ``$PWD`` |
| Supports wildcards: | False |

### -NginxConfigurationFileName
Name / relative path (to ``WorkingDirectory``) of the nginx configuration template.

| | |
| -- | -- |
| Type: | ``String`` |
| Default value: | ``nginx.template`` |
| Supports wildcards: | False |

### -NginxConfigurationDestinationFileName
Name / relative path (to ``WorkingDirectory``) of the generated nginx configuration file.

| | |
| -- | -- |
| Type: | ``String`` |
| Default value: | ``nginx.conf`` |
| Supports wildcards: | False |

### -NginxConfigurationFile
Path of the nginx configuration template.

| | |
| -- | -- |
| Type: | ``String`` |
| Default value: | None |
| Supports wildcards: | False |

### -NginxConfigurationDestinationFile
Path of the generated nginx configuration file.

| | |
| -- | -- |
| Type: | ``String`` |
| Default value: | None |
| Supports wildcards: | False |

### -Depth
Maximum recursion depth for ``include`` option. -1 disables the limit. If the maximum depth is reached, offending lines that would recurse get commented out instead.

| | |
| -- | -- |
| Type: | ``Int32`` |
| Default value: | ``99`` |
| Supports wildcards: | False |

### -NoMetadata
Hide metadata information. Hides generation date, time and user from top of file as well as markers for ``include`` options.

| | |
| -- | -- |
| Type: | ``Switch`` |
| Default value: | None |
| Supports wildcards: | False |

## ❗ DISCLAIMER
This script is provided "as is", without warranty of any kind. Use at your own risk. The author assumes no responsibility or liability for any loss, damage, or other problems that may arise from the use, misuse, or inability to use this script. Always review and test the script in a safe environment before running it on important data.

This script is an independent project and is not associated with, endorsed by, or otherwise affiliated with [nginx](https://nginx.org/).