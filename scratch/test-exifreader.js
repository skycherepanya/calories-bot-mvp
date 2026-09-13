const ExifReader = require('exifreader');

async function test() {
    try {
        const res = await fetch("https://github.com/alexziskind1/heic-samples/raw/master/1.heic");
        const arrBuf = await res.arrayBuffer();
        const buffer = Buffer.from(arrBuf);
        try {
            const tags = ExifReader.load(buffer);
            console.log("ExifReader Date:", tags['DateTimeOriginal']?.description);
        } catch(e) {
            console.error("ExifReader error:", e.message);
        }
    } catch (e) {
        console.error("Fetch error", e);
    }
}
test();
