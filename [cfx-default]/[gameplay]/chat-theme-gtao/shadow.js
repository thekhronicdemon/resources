(function() {
    const BUBBLE_CLASSES = [
        'prp-default',
        'prp-ooc',
        'prp-system',
        'prp-invalid',
        'prp-admin',
        'prp-police',
        'prp-resource',
        'prp-resource-start',
        'prp-resource-stop',
        'prp-resource-build',
        'prp-error'
    ];

    function cleanText(value) {
        return String(value || '')
            .replace(/<div[^>]*prp-msg[^>]*>/gi, '')
            .replace(/<\/?(div|span|br)[^>]*>/gi, ' ')
            .replace(/\s*data-[\w-]+\s*=\s*("[^"]*"|'[^']*')/gi, '')
            .replace(/^\s*>+\s*/, '')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function getText(el) {
        const t = el.querySelector('.prp-text');
        return cleanText(t ? t.textContent : el.textContent);
    }

    function getHeader(el) {
        const h = el.querySelector('.prp-header');
        return cleanText(h ? h.textContent : '');
    }

    function resetClass(el, nextClass) {
        BUBBLE_CLASSES.forEach(function(cls) { el.classList.remove(cls); });
        el.classList.remove('grouped');
        el.classList.add(nextClass);
    }

    function clearWrapperChrome(msg) {
        let node = msg.parentElement;

        while (node && node !== document.body) {
            node.classList.add('prp-wrapper-clear');
            node.style.setProperty('background', 'transparent', 'important');
            node.style.setProperty('background-color', 'transparent', 'important');
            node.style.setProperty('border', '0', 'important');
            node.style.setProperty('box-shadow', 'none', 'important');
            node.style.setProperty('outline', '0', 'important');
            node.style.setProperty('padding', '0', 'important');

            if (node.classList.contains('chat-messages')) break;
            node = node.parentElement;
        }
    }

    function setParts(el, header, text, icon) {
        const headerEl = el.querySelector('.prp-header');
        const textEl = el.querySelector('.prp-text');
        const iconEl = el.querySelector('.prp-icon');

        if (headerEl && header) headerEl.textContent = header;
        if (textEl && text) textEl.textContent = text;
        if (iconEl && icon) iconEl.textContent = icon;
    }

    function classifyText(text, currentClass) {
        const lower = text.toLowerCase();

        if (lower.indexOf('invalid command') !== -1) {
            return { cls: 'prp-invalid', header: 'SERVER', icon: 'ERR', text: 'Invalid Command' };
        }

        if (/\b(stopping|stopped|stop)\s+resource\b/.test(lower)) {
            return { cls: 'prp-resource-stop', header: 'RESOURCE', icon: 'STOP' };
        }

        if (/\b(started|starting|start)\s+resource\b/.test(lower)) {
            return { cls: 'prp-resource-start', header: 'RESOURCE', icon: 'START' };
        }

        if (/\b(creating|created|restarting|refreshing|ensuring|loading)\b/.test(lower) && /\b(resource|script|environment|server)\b/.test(lower)) {
            return { cls: 'prp-resource-build', header: 'RESOURCE', icon: 'LOAD' };
        }

        if (lower.indexOf('resource') !== -1) {
            return { cls: 'prp-resource', header: 'RESOURCE', icon: 'RES' };
        }

        if (/\b(error|failed|failure|exception)\b/.test(lower)) {
            return { cls: 'prp-error', header: 'ERROR', icon: 'ERR' };
        }

        if (currentClass && currentClass !== 'prp-default') {
            return { cls: currentClass };
        }

        return { cls: 'prp-default' };
    }

    function currentBubbleClass(el) {
        return BUBBLE_CLASSES.find(function(cls) { return el.classList.contains(cls); }) || 'prp-default';
    }

    function setupBubble(msg) {
        if (!(msg instanceof HTMLElement)) return;

        const current = currentBubbleClass(msg);
        const text = getText(msg);
        const classification = classifyText(text, current);

        resetClass(msg, classification.cls);
        setParts(msg, classification.header, classification.text, classification.icon);
        clearWrapperChrome(msg);
        bindFade(msg);
    }

    function makeBubble(meta) {
        const msg = document.createElement('div');
        msg.className = 'prp-msg ' + meta.cls;

        const icon = document.createElement('div');
        icon.className = 'prp-icon';
        icon.textContent = meta.icon || 'CHAT';

        const body = document.createElement('div');
        body.className = 'prp-body';

        const header = document.createElement('div');
        header.className = 'prp-header';
        header.textContent = meta.header || 'CHAT';

        const text = document.createElement('div');
        text.className = 'prp-text';
        text.textContent = meta.text || '';

        body.appendChild(header);
        body.appendChild(text);
        msg.appendChild(icon);
        msg.appendChild(body);
        return msg;
    }

    function parsePlainMessage(raw) {
        const text = cleanText(raw);
        const classified = classifyText(text, 'prp-default');
        let header = classified.header || 'CHAT';
        let body = classified.text || text;
        let icon = classified.icon || 'CHAT';

        const speakerMatch = body.match(/^([^:]{2,40}):\s+(.+)$/);
        if (classified.cls === 'prp-default' && speakerMatch) {
            header = cleanText(speakerMatch[1]);
            body = cleanText(speakerMatch[2]);
        }

        return { cls: classified.cls, header: header, text: body, icon: icon };
    }

    function wrapPlainChatMessage(container) {
        if (!(container instanceof HTMLElement)) return;
        const isKnownMessage = container.classList.contains('chat-message');
        const isMessagesChild = container.parentElement && container.parentElement.classList.contains('chat-messages');
        if (!isKnownMessage && !isMessagesChild) return;
        if (container.matches('script, style, input, textarea, form')) return;
        if (container.querySelector('.prp-msg')) {
            Array.from(container.querySelectorAll('.prp-msg')).forEach(setupBubble);
            return;
        }

        const lines = String(container.textContent || '').split(/\n+/).map(cleanText).filter(Boolean);
        if (!lines.length) return;

        container.textContent = '';
        lines.forEach(function(line) {
            const bubble = makeBubble(parsePlainMessage(line));
            container.appendChild(bubble);
            setupBubble(bubble);
        });
    }

    function processNode(node) {
        if (node && node.nodeType === Node.TEXT_NODE && node.parentElement) {
            processNode(node.parentElement.closest('.prp-msg, .chat-message') || node.parentElement);
            return;
        }

        if (!(node instanceof HTMLElement)) return;

        if (node.classList.contains('prp-msg')) setupBubble(node);
        wrapPlainChatMessage(node);

        Array.from(node.querySelectorAll('.prp-msg')).forEach(setupBubble);
        Array.from(node.querySelectorAll('.chat-message, .chat-messages > *')).forEach(wrapPlainChatMessage);
    }

    function bindFade(msg) {
        if (msg.dataset.prpFadeBound === '1') return;
        msg.dataset.prpFadeBound = '1';
        setTimeout(function() { msg.classList.add('fade-out'); }, 120000);
        setTimeout(function() { msg.remove(); }, 121000);
    }

    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            Array.from(mutation.addedNodes).forEach(processNode);
        });
    });

    observer.observe(document.body, { childList: true, subtree: true });
    processNode(document.body);
})();
