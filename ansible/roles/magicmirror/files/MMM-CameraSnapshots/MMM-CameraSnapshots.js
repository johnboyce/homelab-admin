/* MMM-CameraSnapshots — Rotate camera snapshot images from go2rtc
 * Managed by Ansible (magicmirror role).
 *
 * Config:
 *   cameras: [{name, url}, ...]  — go2rtc snapshot URLs
 *   rotateInterval: 30000        — ms between camera switches
 *   refreshInterval: 15000       — ms between image refreshes
 *   width / height               — snapshot display size
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

        setInterval(() => {
            if (this.config.cameras.length > 1) {
                this.currentIndex = (this.currentIndex + 1) % this.config.cameras.length;
            }
            this.updateDom(1000);
        }, this.config.rotateInterval);

        setInterval(() => {
            this.updateDom(0);
        }, this.config.refreshInterval);
    },

    getDom: function () {
        var wrapper = document.createElement("div");
        wrapper.className = "camera-snapshot-wrapper";

        if (this.config.cameras.length === 0) {
            wrapper.innerHTML = "No cameras configured";
            wrapper.className += " dimmed light small";
            return wrapper;
        }

        var camera = this.config.cameras[this.currentIndex];

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
            img.style.display = "none";
            var offline = document.createElement("div");
            offline.className = "camera-offline dimmed light small";
            offline.textContent = camera.name + " — camera sleeping";
            offline.style.width = img.style.width;
            offline.style.height = img.style.height;
            offline.style.display = "flex";
            offline.style.alignItems = "center";
            offline.style.justifyContent = "center";
            offline.style.background = "rgba(0,0,0,0.3)";
            offline.style.borderRadius = "8px";
            wrapper.appendChild(offline);
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
