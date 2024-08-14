<p align="center">
  <a href="https://epic-chain.org">EpicChain</a> HTTP Bridge is a decentralized tool that facilitates seamless integration with the <a href="https://epic-chain.org">EpicChain Network</a> via the HTTP protocol.
</p>

---
![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/epicchainlabs/epicchain-http-bridge?sort=semver)
![License](https://img.shields.io/github/license/epicchainlabs/epicchain-http-bridge.svg?style=popout)


# Overview

EpicChain HTTP Bridge serves as a comprehensive example of how to integrate with the EpicChain network using the HTTP protocol. It enables decentralized storage and retrieval of files within the EpicChain ecosystem for a specified period, allowing users to share content through generated links. EpicChain HTTP Bridge is designed for public testing on the EpicChain network, offering developers a straightforward means of interacting with the blockchain.

# Requirements

- Docker
- Make
- Node.js (`14+`)

# Make Instructions

- Compile the build using `make` (output will be generated in the `epicchain-http-bridge` directory).
- Start the app using `make start PORT=3000` (default PORT is 3000).
- Clean up cache directories using `make clean`.
- Get the release directory with tar.gz using `make release`.

Set variables in the `.env` file before executing the commands:
- `REACT_APP_EPICCHAIN` - Path to EpicChain Bridge
- `REACT_APP_CONTAINER_ID` - EpicChain container ID where objects will be stored
- `REACT_APP_NETMAP_CONTRACT` - EpicChain netmap contract

# EpicChain HTTP Bridge Local Setup

- Start [EpicChain-dev-env](https://github.com/epicchainlabs/EpicChain-dev-env).
- Update `.env`.
- Execute `npm install`.
- Run locally using `npm start`.

# Deployment to Production

Two containers are used: one for website data storage and another for content storage. Nginx is configured to serve both for a single website.

- Create container: `EpicChain-cli --rpc-endpoint st1.storage.epicchain.org:8080 --config CONFIG_PATH container create --policy 'REP 2 IN X CBF 1 SELECT 4 FROM F AS X FILTER "Deployed" EQ "EpicChainLabs" AS F' --basic-acl public-read --await`.

CONFIG_PATH – path to wallet config, wallet config example:
```yaml
wallet: test.json
address: EC1FifWC3F5R9hY3xHyy9UvAAKxGgZfp4W
password: <secret>
```

- Update `/bin/upload.py` script with the actual `cid`.
- Run `make`.
- Untar the archive to a separate directory.
- Copy `/bin/upload.py` to the directory.
- Run `upload.py` to upload EpicChain HTTP Bridge to the EpicChain container.
- Create data container: `EpicChain-cli container create -r st1.storage.epicchain.org:8080 --config CONFIG_PATH --basic-acl 0X0fbfbfff --policy 'REP 2 IN X CBF 2 SELECT 2 FROM F AS X FILTER Deployed EQ EpicChainLabs AS F' --await`.
- Create EACL for it: `EpicChain-cli acl extended create --cid DATA_CID -r 'deny put others' -r 'deny delete others' --out eacl.json`.
- Set EACL for data container: `EpicChain-cli container set-eacl -r st1.storage.epicchain.org:8080 --cid DATA_CID --table eacl.json --config CONFIG_PATH --await`.
- Update nginx.config to use the new container on the production server.

# Nginx Configuration Example on Production Server

```nginx
proxy_cache_path /srv/EpicChain_cache/ levels=1:2 keys_zone=EpicChain_cache:50m max_size=16g inactive=60m use_temp_path=off;

server {
	set $cid HPUKdZBBtD75jDN8iVb3zoaNACWinuf1vF5kkYpMMbap;
	set $data_cid 41tVWBvQVTLGQPHBmXySHsJkcc6X17i39bMuJe9wYhAJ;
	set $EpicChain_http_gateway http.fs.epicchain.org;
	set $rpc rpc.morph.fs.epicchain.org:40341;
	client_max_body_size 100m;
	proxy_connect_timeout 5m;
	proxy_send_timeout    5m;
	proxy_read_timeout    5m;
	send_timeout          5m;
	default_type application/octet-stream;

	location ~ "^\/chain" {
		rewrite ^/chain/(.*) /$1 break;
		proxy_pass https://rpc;
	}

	location /gate/upload/ {
		rewrite ^/gate/(.*) /upload/$data_cid break;
		proxy_pass https://$EpicChain_http_gateway;
		proxy_set_header X-Attribute-email $http_x_attribute_email;
		proxy_set_header X-Attribute-EpicChain-Expiration-Epoch $http_x_attribute_EpicChain_expiration_epoch;
	}

	location ~ "^\/gate\/get(/.*)?\/?$" {
		rewrite ^/gate/get/(.*) /$data_cid/$1 break;
		proxy_pass https://$EpicChain_http_gateway;
		proxy_intercept_errors on;
		proxy_cache_valid 404 0;
		proxy_cache_valid 200 15m;
		proxy_cache EpicChain_cache;
		proxy_cache_methods GET;
	}

	location /signup_google/ {
		proxy_pass http://localhost:8084/login?service=google;
		proxy_intercept_errors on;
		proxy_set_header Host              $http_host;
		proxy_set_header X-Real-IP         $remote_addr;
		proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}

	location /signup_github/ {
		proxy_pass http://localhost:8084/login?service=github;
		proxy_intercept_errors on;
		proxy_set_header Host              $http_host;
		proxy_set_header X-Real-IP         $remote_addr;
		proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}

	location ~ "^\/callback" {
		rewrite ^/callback\?(.*) /$1 break;
		proxy_pass http://localhost:8084;
	}

	location /load {
		rewrite '^(/.*)$' /get_by_attribute/$cid/FileName/index.html break;
		proxy_pass https://$EpicChain_http_gateway;
	}

	location /toc {
		rewrite '^(/.*)$' /get_by_attribute/$cid/FileName/index.html break;
		proxy_pass https://$EpicChain_http_gateway;
	}

	location / {
		rewrite '^(/[0-9a-zA-Z\-]{43,44})$' /get/$cid/$1 break;
		rewrite '^/$'                       /get_by_attribute/$cid/FileName/index.html break;
		rewrite '^/([^/]*)$'                /get_by_attribute/$cid/FileName/$1 break;
		rewrite '^(/.*)$'                   /get_by_attribute/$cid/FilePath/$1 break;
		proxy_pass https://$EpicChain_http_gateway;
	}
}
```

# License

- [GNU General Public License v3.0](LICENSE)