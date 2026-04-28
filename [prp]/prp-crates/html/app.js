const { createApp } = Vue;

createApp({
    data() {
        return {
            visible: false,
            items: [],
            winningIndex: 0,
            duration: 6500,
            cardWidth: 170,
            cardGap: 14,
            translateX: 0,
            animating: false,
            finishTimer: null,
        };
    },

    computed: {
        stripStyle() {
            return {
                transform: `translateX(${this.translateX}px)`,
                transition: this.animating ? `transform ${this.duration}ms cubic-bezier(0.08, 0.72, 0.14, 1)` : 'none',
            };
        }
    },

    methods: {
        formatPercent(value) {
            const num = Number(value) || 0;
            return num.toFixed(num >= 10 ? 1 : 2).replace(/\.00$/, '');
        },

        resetState() {
            this.items = [];
            this.winningIndex = 0;
            this.translateX = 0;
            this.animating = false;
            if (this.finishTimer) {
                clearTimeout(this.finishTimer);
                this.finishTimer = null;
            }
        },

        close() {
            this.visible = false;
            this.resetState();
        },

        open(payload) {
            this.resetState();
            this.visible = true;
            this.items = Array.isArray(payload.items) ? payload.items : [];
            this.winningIndex = Number(payload.winningIndex) || 1;
            this.duration = Number(payload.duration) || 6500;
            this.cardWidth = Number(payload.cardWidth) || 170;
            this.cardGap = Number(payload.cardGap) || 14;

            document.documentElement.style.setProperty('--card-width', `${this.cardWidth}px`);
            document.documentElement.style.setProperty('--card-gap', `${this.cardGap}px`);

            this.$nextTick(() => {
                const shell = document.querySelector('.crate-strip-shell');
                const shellWidth = shell ? shell.clientWidth : 1200;
                const targetCenter = shellWidth / 2;
                const cardFullWidth = this.cardWidth + this.cardGap;
                const targetX = -(((this.winningIndex - 1) * cardFullWidth) - targetCenter + (this.cardWidth / 2) + 40);
                const randomNudge = Math.floor(Math.random() * 20) - 10;

                this.translateX = 0;

                requestAnimationFrame(() => {
                    requestAnimationFrame(() => {
                        this.animating = true;
                        this.translateX = targetX + randomNudge;
                    });
                });

                this.finishTimer = setTimeout(() => {
                    fetch(`https://${GetParentResourceName()}/rollFinished`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ ok: true })
                    }).finally(() => {
                        this.close();
                    });
                }, this.duration + 250);
            });
        }
    },

    mounted() {
        window.addEventListener('message', (event) => {
            const data = event.data || {};
            if (data.action === 'open' && data.payload) {
                this.open(data.payload);
            } else if (data.action === 'close') {
                this.close();
            }
        });
    }
}).mount('#app');
