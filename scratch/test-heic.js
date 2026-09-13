const exifr = require('exifr');

async function test() {
    try {
        const res = await fetch("https://github.com/alexziskind1/heic-samples/raw/master/1.heic");
        const arrBuf = await res.arrayBuffer();
        const buffer = Buffer.from(arrBuf);
        try {
            const exif = await exifr.parse(buffer);
            console.log("Buffer EXIF:", Object.keys(exif || {}));
        } catch(e) {
            console.error("Buffer error:", e.message);
        }
        
        try {
            const exif2 = await exifr.parse(arrBuf);
            console.log("ArrayBuffer EXIF:", Object.keys(exif2 || {}));
        } catch(e) {
            console.error("ArrayBuffer error:", e.message);
        }
    } catch (e) {
        console.error("Fetch error", e);
    }
}
test();
