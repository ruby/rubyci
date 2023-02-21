// Entry point for the build script in your package.json
import $ from 'jquery'
import {} from 'jquery-ujs'
import * as bootstrap from "bootstrap"

$(function() {
    $("a[rel=popover]").popover();
    $(".tooltip").tooltip();
    return $("a[rel=tooltip]").tooltip();
});
