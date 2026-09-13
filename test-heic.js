const fs = require('fs');

async function testExifr(buffer) {
    try {
        const exifr = require('exifr');
        const tags = await exifr.parse(buffer);
        console.log("exifr tags keys:", Object.keys(tags || {}));
    } catch(e) {
        console.error("exifr failed:", e.message);
    }
}

async function testExifReader(buffer) {
    try {
        const ExifReader = require('exifreader');
        const tags = ExifReader.load(buffer);
        console.log("ExifReader Date:", tags['DateTimeOriginal']?.description);
    } catch(e) {
        console.error("ExifReader failed:", e.message);
    }
}

async function run() {
    const buffer = fs.readFileSync('scratch/real.heic');
    await testExifr(buffer);
    await testExifReader(buffer);
}

run();
