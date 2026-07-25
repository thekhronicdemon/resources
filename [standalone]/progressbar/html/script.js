document.addEventListener("DOMContentLoaded", (event) => {
    var ProgressBar = {
        init: function () {
            this.progressLabel = document.getElementById("progress-label");
            this.progressPercentage = document.getElementById("progress-percentage");
            this.progressBar = document.getElementById("progress-bar");
            this.progressContainer = document.querySelector(".progress-container");
            this.progressIconImage = document.getElementById("progress-icon-image");
            this.progressIconFallback = document.getElementById("progress-icon-fallback");
            this.animationFrameRequest = null;
            this.setupListeners();
        },

        setupListeners: function () {
            window.addEventListener("message", function (event) {
                if (event.data.action === "progress") {
                    ProgressBar.update(event.data);
                } else if (event.data.action === "cancel") {
                    ProgressBar.cancel();
                }
            });
        },

        resolveIconSource: function (icon) {
            if (!icon) return "";

            const rawIcon = String(icon).trim();
            if (!rawIcon) return "";
            if (/^(https?:|nui:|\.\/|\/)/i.test(rawIcon)) return rawIcon;
            if (/\.(png|jpe?g|webp|gif|svg)$/i.test(rawIcon)) {
                return `nui://prp-inventory/html/images/${rawIcon}`;
            }

            return "";
        },

        getFallbackText: function (label) {
            const cleanedLabel = String(label || "Progress").trim();
            return cleanedLabel ? cleanedLabel.charAt(0).toUpperCase() : "P";
        },

        setIcon: function (icon, label) {
            const iconSource = this.resolveIconSource(icon);
            this.progressIconFallback.textContent = this.getFallbackText(label);

            if (iconSource) {
                this.progressIconImage.hidden = false;
                this.progressIconImage.src = iconSource;
                this.progressIconImage.onerror = () => {
                    this.progressIconImage.hidden = true;
                };
                return;
            }

            this.progressIconImage.removeAttribute("src");
            this.progressIconImage.hidden = true;
        },

        update: function (data) {
            if (this.animationFrameRequest) {
                cancelAnimationFrame(this.animationFrameRequest);
            }
            clearTimeout(this.cancelledTimer);

            this.progressLabel.textContent = data.label;
            this.progressPercentage.textContent = "0%";
            this.setIcon(data.icon, data.label);
            this.progressContainer.style.display = "block";
            let startTime = Date.now();
            let duration = parseInt(data.duration, 10);

            const animateProgress = () => {
                let timeElapsed = Date.now() - startTime;
                let progress = timeElapsed / duration;
                if (progress > 1) progress = 1;
                let percentage = Math.round(progress * 100);
                this.progressBar.style.width = percentage + "%";
                this.progressPercentage.textContent = percentage + "%";
                if (progress < 1) {
                    this.animationFrameRequest = requestAnimationFrame(animateProgress);
                } else {
                    this.onComplete();
                }
            };
            this.animationFrameRequest = requestAnimationFrame(animateProgress);
        },

        cancel: function () {
            if (this.animationFrameRequest) {
                cancelAnimationFrame(this.animationFrameRequest);
                this.animationFrameRequest = null;
            }
            this.progressLabel.textContent = "CANCELLED";
            this.progressPercentage.textContent = "";
            this.progressBar.style.width = "100%";
            this.cancelledTimer = setTimeout(this.onCancel.bind(this), 1000);
        },

        onComplete: function () {
            this.progressContainer.style.display = "none";
            this.progressBar.style.width = "0";
            this.progressPercentage.textContent = "";
            this.postAction("FinishAction");
        },

        onCancel: function () {
            this.progressContainer.style.display = "none";
            this.progressBar.style.width = "0";
            this.progressPercentage.textContent = "";
        },

        postAction: function (action) {
            fetch(`https://progressbar/${action}`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({}),
            });
        },

        closeUI: function () {
            let mainContainer = document.querySelector(".main-container");
            if (mainContainer) {
                mainContainer.style.display = "none";
            }
        },
    };

    ProgressBar.init();
});
