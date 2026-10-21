const xliveWebOrigin = 'https://xlive-web.vercel.app';

String mediaShareUrl(String mediaId) => '$xliveWebOrigin/media/$mediaId';

String profileShareUrl(String userId) => '$xliveWebOrigin/profile/$userId';
