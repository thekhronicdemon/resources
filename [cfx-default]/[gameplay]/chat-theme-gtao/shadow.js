(function() {
    function allMsgs() {
        return Array.from(document.querySelectorAll('.prp-msg'));
    }

    function getText(el) {
        const t = el.querySelector('.prp-text');
        return t ? t.textContent.trim().toLowerCase() : '';
    }

    function getHeader(el) {
        const h = el.querySelector('.prp-header');
        return h ? h.textContent.trim().toLowerCase() : '';
    }

    function classify(el) {
        const txt = getText(el);
        const hdr = getHeader(el);

        if (txt.indexOf('invalid command') !== -1 || hdr.indexOf('invalid command') !== -1) {
            el.classList.remove('prp-default', 'prp-ooc', 'prp-system', 'prp-admin', 'prp-police');
            el.classList.add('prp-invalid');

            const header = el.querySelector('.prp-header');
            const text = el.querySelector('.prp-text');
            const icon = el.querySelector('.prp-icon');

            if (header) header.textContent = 'SERVER';
            if (text) text.textContent = 'Invalid Command';
            if (icon) icon.textContent = '⚠️';
        }
    }

    function applyGrouping(msg) {
        const list = allMsgs();
        const idx = list.indexOf(msg);
        if (idx <= 0) return;
        const prev = list[idx - 1];
        if (!prev) return;

        const sameAuthor = (prev.dataset.author || '') === (msg.dataset.author || '');
        const sameTemplate = (prev.dataset.template || '') === (msg.dataset.template || '');

        if (sameAuthor && sameTemplate && !msg.classList.contains('prp-invalid') && !msg.classList.contains('prp-system')) {
            msg.classList.add('grouped');
        }
    }

    function bindFade(msg) {
        if (msg.dataset.fadeBound === '1') return;
        msg.dataset.fadeBound = '1';
        setTimeout(function() { msg.classList.add('fade-out'); }, 120000);
        setTimeout(function() { msg.remove(); }, 121000);
    }

    function setup(msg) {
        classify(msg);
        bindFade(msg);
        requestAnimationFrame(function() { applyGrouping(msg); });
    }

    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(m) {
            Array.from(m.addedNodes).forEach(function(node) {
                if (!(node instanceof HTMLElement)) return;

                let msgs = [];
                if (node.classList && node.classList.contains('prp-msg')) {
                    msgs = [node];
                } else if (node.querySelectorAll) {
                    msgs = Array.from(node.querySelectorAll('.prp-msg'));
                }

                msgs.forEach(setup);
            });
        });
    });

    observer.observe(document.body, { childList: true, subtree: true });
    allMsgs().forEach(setup);
})();
