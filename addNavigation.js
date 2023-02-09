const fs = require('fs');

const jsdom = require("jsdom");
const { JSDOM } = jsdom;


async function main() {
    let navigationString = fs.readFileSync('./navigation.html').toString();
    let navigation = JSDOM.fragment(navigationString);

    let dom = await JSDOM.fromFile('./site/index.html');
    const { document } = dom.window;

    let body = document.querySelectorAll('body')[0];
    console.dir(body);
    body.prepend(navigation);

    process.stdout.write(dom.serialize());
}

main().catch(console.error);


