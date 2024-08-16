#!/usr/bin/env node

/**
 * Obscuring emails is a bit of an open question. I couldn't find any techniques
 * that worked perfectly for every case - screen readers, assistive devices, copy & paste,
 * mobile browsers.
 */

const fs = require('fs');
const { JSDOM: jsdom } = require("jsdom");

const reverseClass = 'reverse';

const styleString = `<style type="text/css">
    a.${reverseClass} {
        unicode-bidi: bidi-override; 
        direction: rtl;
    }
</style>`;
const style = jsdom.fragment(styleString);


async function main() {
    let dom = new jsdom(fs.readFileSync('/dev/stdin').toString());
    const { document } = dom.window;

    const head = document.querySelectorAll('head')[0];
    head.append(style);

    const body = document.querySelectorAll('body')[0];

    body.querySelectorAll('a').forEach(anchor => {
        const href = anchor.getAttribute('href');
        if (href.startsWith('mailto:')) {
            anchor.textContent = anchor.textContent.replace('@', ' at ');
            // obscure mailto: link
            const address = href.substr('mailto:'.length);
 
            // url-encoding - this is not very effective but better than nothing,
            // and some screen readers should be okay with it.
            const obscuredAddress = address
                .split('')
                .map(char => `%${char.codePointAt(0).toString(16)}`)
                .join('');
            anchor.setAttribute('href', `mailto:${obscuredAddress}?subject=Hi,+Neil`);
        }

    });

    process.stdout.write(dom.serialize());
}

main().catch(console.error);