// Entry point for the build script in your package.json
import * as Popper from "@popperjs/core"
import * as Bootstrap from "bootstrap"

document.addEventListener('DOMContentLoaded' ,function() {
    $("a[rel=popover]").popover();
    $(".tooltip").tooltip();
    return $("a[rel=tooltip]").tooltip();
});
