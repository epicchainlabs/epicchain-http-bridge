const server = process.env.REACT_APP_NEOFS;

type Methods = "GET" | "POST" | "HEAD";

export interface ObjectData {
	objectId?: string | null
	containerId?: string | null
	ownerId?: string | null
	filename?: string | null
	size?: string | null
	expirationEpoch?: string | null
}

async function serverRequest(method: Methods, url: string, params: object, headers: any) {
	const json: any = {
		method,
		headers,
	}

	if (json['headers']['Content-Type'] === 'multipart/form-data') {
		json['body'] = params;
		delete json['headers']['Content-Type'];
	} else if (Object.keys(params).length > 0) {
		json['body'] = JSON.stringify(params);
		json['headers']['Content-Type'] = 'application/json';
	}

	let activeUrl: string = url;
	if (server) {
		activeUrl = `${server}${url}`;
	}

	return fetch(activeUrl, json).catch((error: any) => {
		console.log(error);
	});
}

export default function api(method: Methods, url: string, params: object = {}, headers: object = {}) {
	return new Promise((resolve, reject) => {
		serverRequest(method, url, params, headers).then(async (response: any) => {
			if (response && response.status === 204) {
				resolve({ status: 'success' });
			} else {
				let res: any = response;
				if (method === 'HEAD' && response.status !== 200) {
					reject(res);
				} else if (method === 'HEAD' && response.headers) {
					const res: ObjectData = {
						'filename': response.headers.get('X-Attribute-Filename'),
						'containerId': response.headers.get('X-Container-Id'),
						'ownerId': response.headers.get('X-Owner-Id'),
						'size': response.headers.get('Content-Length') ? response.headers.get('Content-Length') : response.headers.get('x-neofs-payload-length'),
						'expirationEpoch': response.headers.get('X-Attribute-Neofs-Expiration-Epoch'),
					}
					resolve(res);
				} else if (method === 'GET' && url.indexOf(`/gate/get/`) !== -1) {
					res = await response.blob();
					resolve(res);
				} else if (response && response.status === 200) {
					res = await response.json();
					resolve(res);
				} else {
					reject(res);
				}
			}
		});
	});
}
