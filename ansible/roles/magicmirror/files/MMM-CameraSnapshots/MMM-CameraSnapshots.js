/* MMM-CameraSnapshots — Rotate camera snapshot images from go2rtc
 * Managed by Ansible (magicmirror role).
 *
 * Config:
 *   cameras: [{name, url}, ...]  — go2rtc snapshot URLs
 *   rotateInterval: 30000        — ms between camera switches
 *   refreshInterval: 15000       — ms between image refreshes
 *   width / height               — snapshot display size
 *
 * Fallback: when the live snapshot fails (camera sleeping), the module
 * loads a cached image from /modules/MMM-CameraSnapshots/cache/<name>.jpg
 * saved by the magicmirror-snapshot-cache timer.
 */
Module.register("MMM-CameraSnapshots", {
    defaults: {
        cameras: [],
        rotateInterval: 30000,
        refreshInterval: 15000,
        width: "480px",
        height: "360px",
    },

    start: function () {
        this.currentIndex = 0;
        this.cacheTimestamps = {};
        this.loadCacheTimestamps();

        setInterval(() => {
            if (this.config.cameras.length > 1) {
                this.currentIndex = (this.currentIndex + 1) % this.config.cameras.length;
            }
            this.updateDom(1000);
        }, this.config.rotateInterval);

        setInterval(() => {
            this.updateDom(0);
        }, this.config.refreshInterval);

        // Refresh cache timestamps every 60 seconds
        setInterval(() => {
            this.loadCacheTimestamps();
        }, 60000);
    },

    loadCacheTimestamps: function () {
        var self = this;
        this.config.cameras.forEach(function (camera) {
            var key = camera.name.toLowerCase();
            var tsUrl = "/modules/MMM-CameraSnapshots/cache/" + key + ".ts?t=" + Date.now();
            fetch(tsUrl)
                .then(function (r) { return r.ok ? r.text() : null; })
                .then(function (text) {
                    if (text) {
                        self.cacheTimestamps[key] = parseInt(text.trim(), 10);
                    }
                })
                .catch(function () {});
        });
    },

    formatAge: function (epochSecs) {
        var ageSecs = Math.floor(Date.now() / 1000) - epochSecs;
        if (ageSecs < 60) return "just now";
        if (ageSecs < 3600) return Math.floor(ageSecs / 60) + "m ago";
        if (ageSecs < 86400) return Math.floor(ageSecs / 3600) + "h ago";
        return Math.floor(ageSecs / 86400) + "d ago";
    },

    getDom: function () {
        var self = this;
        var wrapper = document.createElement("div");
        wrapper.className = "camera-snapshot-wrapper";

        if (this.config.cameras.length === 0) {
            wrapper.innerHTML = "No cameras configured";
            wrapper.className += " dimmed light small";
            return wrapper;
        }

        var camera = this.config.cameras[this.currentIndex];
        var cacheKey = camera.name.toLowerCase();

        var label = document.createElement("div");
        label.className = "camera-label small bright";
        label.textContent = camera.name;
        wrapper.appendChild(label);

        var img = document.createElement("img");
        img.src = camera.url + (camera.url.includes("?") ? "&" : "?") + "t=" + Date.now();
        img.style.width = this.config.width;
        img.style.height = this.config.height;
        img.style.objectFit = "cover";
        img.style.borderRadius = "8px";
        img.alt = camera.name;

        img.onerror = function () {
            // Live snapshot failed — try cached image
            var cacheUrl = "/modules/MMM-CameraSnapshots/cache/" + cacheKey + ".jpg?t=" + Date.now();
            var cachedImg = document.createElement("img");
            cachedImg.src = cacheUrl;
            cachedImg.style.width = self.config.width;
            cachedImg.style.height = self.config.height;
            cachedImg.style.objectFit = "cover";
            cachedImg.style.borderRadius = "8px";
            cachedImg.style.opacity = "0.7";
            cachedImg.alt = camera.name + " (cached)";

            cachedImg.onload = function () {
                // Cached image loaded — show it with age label
                img.style.display = "none";
                wrapper.appendChild(cachedImg);

                var ts = self.cacheTimestamps[cacheKey];
                if (ts) {
                    var age = document.createElement("div");
                    age.className = "camera-cache-age dimmed light xsmall";
                    age.textContent = "Last capture: " + self.formatAge(ts);
                    wrapper.appendChild(age);
                }
            };

            cachedImg.onerror = function () {
                // No cache either — show offline message
                img.style.display = "none";
                var offline = document.createElement("div");
                offline.className = "camera-offline dimmed light small";
                offline.textContent = camera.name + " — camera sleeping";
                offline.style.width = self.config.width;
                offline.style.height = self.config.height;
                offline.style.display = "flex";
                offline.style.alignItems = "center";
                offline.style.justifyContent = "center";
                offline.style.background = "rgba(0,0,0,0.3)";
                offline.style.borderRadius = "8px";
                wrapper.appendChild(offline);
            };
        };

        wrapper.appendChild(img);

        if (this.config.cameras.length > 1) {
            var dots = document.createElement("div");
            dots.className = "camera-dots";
            for (var i = 0; i < this.config.cameras.length; i++) {
                var dot = document.createElement("span");
                dot.className = "camera-dot" + (i === this.currentIndex ? " active" : "");
                dots.appendChild(dot);
            }
            wrapper.appendChild(dots);
        }

        return wrapper;
    },

    getStyles: function () {
        return ["MMM-CameraSnapshots.css"];
    },
});
