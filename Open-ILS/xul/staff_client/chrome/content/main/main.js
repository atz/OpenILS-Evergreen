dump('entering main/main.js\n');
// vim:noet:sw=4:ts=4:

var xulG;
var offlineStrings;
var authStrings;
var openTabs = new Array();
var tempWindow = null;
var tempFocusWindow = null;

function grant_perms(url) {
    var perms = "UniversalXPConnect UniversalPreferencesWrite UniversalBrowserWrite UniversalPreferencesRead UniversalBrowserRead UniversalFileRead";
    dump('Granting ' + perms + ' to ' + url + '\n');
    if (G.pref) {
        G.pref.setCharPref("capability.principal.codebase.p0.granted", perms);
        G.pref.setCharPref("capability.principal.codebase.p0.id", url);
        G.pref.setCharPref("capability.principal.codebase.p1.granted", perms);
        G.pref.setCharPref("capability.principal.codebase.p1.id", url.replace('http:','https:'));
        G.pref.setBoolPref("dom.disable_open_during_load",false);
        G.pref.setBoolPref("browser.popups.showPopupBlocker",false);
    }

}

function clear_the_cache() {
    try {
        var cacheClass         = Components.classes["@mozilla.org/network/cache-service;1"];
        var cacheService    = cacheClass.getService(Components.interfaces.nsICacheService);
        cacheService.evictEntries(Components.interfaces.nsICache.STORE_ON_DISK);
        cacheService.evictEntries(Components.interfaces.nsICache.STORE_IN_MEMORY);
    } catch(E) {
        dump(E+'\n');alert(E);
    }
}

function toOpenWindowByType(inType, uri) { /* for Venkman */
    try {
        var winopts = "chrome,extrachrome,menubar,resizable,scrollbars,status,toolbar";
        window.open(uri, "_blank", winopts);
    } catch(E) {
        alert(E); throw(E);
    }
}

function start_debugger() {
    setTimeout(
        function() {
            try { start_venkman(); } catch(E) { alert(E); }
        }, 0
    );
};

function start_inspector() {
    setTimeout(
        function() {
            try { inspectDOMDocument(); } catch(E) { alert(E); }
        }, 0
    );
};

function start_chrome_list() {
    setTimeout(
        function() {
            try { startChromeList(); } catch(E) { alert(E); }
        }, 0
    );
};

function start_js_shell() {
    setTimeout(
        function() {
            try { window.open('chrome://open_ils_staff_client/content/util/shell.html','shell','chrome,resizable,scrollbars'); } catch(E) { alert(E); }
        }, 0
    );
};

function new_tabs(aTabList, aContinue) {
    if(aTabList != null) {
        openTabs = openTabs.concat(aTabList);
    }
    if(G.data.session) { // Just add to the list of stuff to open unless we are logged in
        netscape.security.PrivilegeManager.enablePrivilege("UniversalXPConnect");
        var targetwindow = null;
        var focuswindow = null;
        var focustab = {'focus' : true};
        if(aContinue == true && tempWindow.closed == false) {
            if(tempWindow.g == undefined || tempWindow.g.menu == undefined) {
                setTimeout(
                    function() {
                        new_tabs(null, true);
                    }, 300);
                return null;
            }
            targetwindow = tempWindow;
            tempWindow = null;
            focuswindow = tempFocusWindow;
            tempFocusWindow = null;
            focustab = {'nofocus' : true};
        }
        else if(tempWindow != null) { // In theory, we are waiting on a setTimeout
            if(tempWindow.closed == true) // But someone closed our window?
            {
                tempWindow = null;
                tempFocusWindow = null;
            }
            else
            {
                return null;
            }
        }
        var newTab;
        var firstURL;
        var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"].
            getService(Components.interfaces.nsIWindowMediator);
            // This may look out of place, but this is so we can continue this loop from down below
opentabs:
            while(openTabs.length > 0) {
            newTab = openTabs.shift();
            if(newTab == 'new' || newTab == 'init') {
                if(newTab != 'init' && openTabs.length > 0 && openTabs[0] != 'new') {
                    firstURL = openTabs.shift();
                    if(firstURL != 'tab') { // 'new' followed by 'tab' should be equal to 'init' in functionality, this should do that
                        if(urls[firstURL]) {
                            firstURL = urls[firstURL];
                        }
                        firstURL = '&firstURL=' + window.escape(firstURL);
                    }
                    else {
                        firstURL = '';
                    }
                }
                else {
                    firstURL = '';
                }
                targetwindow = xulG.window.open(urls.XUL_MENU_FRAME
                    + '?server='+window.escape(G.data.server) + firstURL,
                    '_blank','chrome,resizable'
                );
                targetwindow.xulG = xulG;
                if (focuswindow == null) {
                    focuswindow = targetwindow;
                }
                tempWindow = targetwindow;
                tempFocusWindow = focuswindow;
                setTimeout(
                    function() {
                        new_tabs(null, true);
                    }, 300);
                return null;
            }
            else {
                if(newTab == 'tab') {
                    newTab = null;
                }
                else if(urls[newTab]) {
                    newTab = urls[newTab];
                }
                if(targetwindow != null) { // Already have a previous target window? Use it first.
                    if(targetwindow.g.menu.new_tab(newTab,focustab,null)) {
                        focustab = {'nofocus' : true};
                        continue;
                    }
                }
                var enumerator = wm.getEnumerator('eg_menu');
                while(enumerator.hasMoreElements()) {
                    targetwindow = enumerator.getNext();
                    if(targetwindow.g.menu.new_tab(newTab,focustab,null)) {
                        focustab = {'nofocus' : true};
                        if (focuswindow == null) {
                            focuswindow = targetwindow;
                        }
                        continue opentabs;
                    }
                }
                // No windows found to add the tab to? Make a new one.
                if(newTab == null) { // Were we making a "default" tab?
                    openTabs.unshift('init'); // 'init' does that for us!
                }
                else {
                    openTabs.unshift('new',newTab);
                }
            }
        }
        if(focuswindow != null) {
            focuswindow.focus();
        }
    }
}

function main_init() {
    dump('entering main_init()\n');
    try {
        clear_the_cache();
        if("arguments" in window && window.arguments.length > 0 && window.arguments[0].wrappedJSObject != undefined && window.arguments[0].wrappedJSObject.openTabs != undefined) {
            openTabs = openTabs.concat(window.arguments[0].wrappedJSObject.openTabs);
        }

        // Now we can safely load the strings without the cache getting wiped
        offlineStrings = document.getElementById('offlineStrings');
        authStrings = document.getElementById('authStrings');

        if (typeof JSAN == 'undefined') {
            throw(
                offlineStrings.getString('common.jsan.missing')
            );
        }
        /////////////////////////////////////////////////////////////////////////////

        JSAN.errorLevel = "die"; // none, warn, or die
        JSAN.addRepository('..');

        //JSAN.use('test.test'); test.test.hello_world();

        var mw = self;
        G =  {};
        
        G.pref = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefBranch);

        JSAN.use('util.error');
        G.error = new util.error();
        G.error.sdump('D_ERROR', offlineStrings.getString('main.testing'));

        JSAN.use('util.window');
        G.window = new util.window();

        JSAN.use('auth.controller');
        G.auth = new auth.controller( { 'window' : mw } );

        JSAN.use('OpenILS.data');
        G.data = new OpenILS.data();
        G.data.on_error = G.auth.logoff;

        JSAN.use('util.file');
        G.file = new util.file();
        try {
            G.file.get('ws_info');
            G.ws_info = G.file.get_object(); G.file.close();
        } catch(E) {
            G.ws_info = {};
        }
        G.data.ws_info = G.ws_info; G.data.stash('ws_info');

        G.auth.on_login = function() {

            var url = G.auth.controller.view.server_prompt.value || urls.remote;

            G.data.server_unadorned = url; G.data.stash('server_unadorned'); G.data.stash_retrieve();

            if (! url.match( '^http://' ) ) { url = 'http://' + url; }

            G.data.server = url; G.data.stash('server'); 
            G.data.session = { 'key' : G.auth.session.key, 'auth' : G.auth.session.authtime }; G.data.stash('session');
            G.data.stash_retrieve();
            try {
                var ios = Components.classes["@mozilla.org/network/io-service;1"].getService(Components.interfaces.nsIIOService);
                var cookieUri = ios.newURI("http://" + G.data.server_unadorned, null, null);
                var cookieUriSSL = ios.newURI("https://" + G.data.server_unadorned, null, null);
                var cookieSvc = Components.classes["@mozilla.org/cookieService;1"].getService(Components.interfaces.nsICookieService);

                cookieSvc.setCookieString(cookieUri, null, "ses="+G.data.session.key, null);
                cookieSvc.setCookieString(cookieUriSSL, null, "ses="+G.data.session.key, null);
                cookieSvc.setCookieString(cookieUri, null, "xul=1", null);
                cookieSvc.setCookieString(cookieUriSSL, null, "xul=1", null);

            } catch(E) {
                alert(offlineStrings.getFormattedString(main.session_cookie.error, [E]));
            }

            grant_perms(url);

            xulG = {
                'auth' : G.auth,
                'url' : url,
                'window' : G.window,
                'data' : G.data,
                'pref' : G.pref
            };

            if (G.data.ws_info && G.data.ws_info[G.auth.controller.view.server_prompt.value]) {
                JSAN.use('util.widgets');
                var deck = document.getElementById('progress_space');
                util.widgets.remove_children( deck );
                var iframe = document.createElement('iframe'); deck.appendChild(iframe);
                iframe.setAttribute( 'src', url + urls.XUL_LOGIN_DATA );
                iframe.contentWindow.xulG = xulG;
                G.data_xul = iframe.contentWindow;
            } else {
                xulG.file = G.file;
                var deck = G.auth.controller.view.ws_deck;
                JSAN.use('util.widgets'); util.widgets.remove_children('ws_deck');
                var iframe = document.createElement('iframe'); deck.appendChild(iframe);
                iframe.setAttribute( 'src', url + urls.XUL_WORKSTATION_INFO );
                iframe.contentWindow.xulG = xulG;
                deck.selectedIndex = deck.childNodes.length - 1;
            }
        };

        G.auth.on_standalone = function() {
            try {
                G.window.open(urls.XUL_STANDALONE,'Offline','chrome,resizable');
            } catch(E) {
                alert(E);
            }
        };

        G.auth.on_standalone_export = function() {
            try {
                JSAN.use('util.file'); var file = new util.file('pending_xacts');
                if (file._file.exists()) {
                    var file2 = new util.file('');
                    var f = file2.pick_file( { 'mode' : 'save', 'title' : offlineStrings.getString('main.transaction_export.title') } );
                    if (f) {
                        if (f.exists()) {
                            var r = G.error.yns_alert(
                                offlineStrings.getFormattedString('main.transaction_export.prompt', [f.leafName]),
                                offlineStrings.getString('main.transaction_export.prompt.title'),
                                offlineStrings.getString('common.yes'),
                                offlineStrings.getString('common.no'),
                                null,
                                offlineStrings.getString('common.confirm')
                            );
                            if (r != 0) { file.close(); return; }
                        }
                        var e_file = new util.file(''); e_file._file = f;
                        e_file.write_content( 'truncate', file.get_content() );
                        e_file.close();
                        var r = G.error.yns_alert(
                            offlineStrings.getFormattedString('main.transaction_export.success.prompt', [f.leafName]),
                            offlineStrings.getString('main.transaction_export.success.title'),
                            offlineStrings.getString('common.yes'),
                            offlineStrings.getString('common.no'),
                            null,
                            offlineStrings.getString('common.confirm')
                        );
                        if (r == 0) {
                            var count = 0;
                            var filename = 'pending_xacts_exported_' + new Date().getTime();
                            var t_file = new util.file(filename);
                            while (t_file._file.exists()) {
                                filename = 'pending_xacts_' + new Date().getTime() + '.exported';
                                t_file = new util.file(filename);
                                if (count++ > 100) {
                                    throw(offlineStrings.getString('main.transaction_export.filename.error'));
                                }
                            }
                            file.close(); file = new util.file('pending_xacts'); // prevents a bug with .moveTo below
                            file._file.moveTo(null,filename);
                        } else {
                            alert(offlineStrings.getString('main.transaction_export.duplicate.warning'));
                        }
                    } else {
                        alert(offlineStrings.getString('main.transaction_export.no_filename.error'));
                    }
                } else {
                    alert(offlineStrings.getString('main.transaction_export.no_transactions.error'));
                }
                file.close();
            } catch(E) {
                alert(E);
            }
        };

        G.auth.on_standalone_import = function() {
            try {
                JSAN.use('util.file'); var file = new util.file('pending_xacts');
                if (file._file.exists()) {
                    alert(offlineStrings.getString('main.transaction_import.outstanding.error'));
                } else {
                    var file2 = new util.file('');
                    var f = file2.pick_file( { 'mode' : 'open', 'title' : offlineStrings.getString('main.transaction_import.title')} );
                    if (f && f.exists()) {
                        var i_file = new util.file(''); i_file._file = f;
                        file.write_content( 'truncate', i_file.get_content() );
                        i_file.close();
                        var r = G.error.yns_alert(
                            offlineStrings.getFormattedString('main.transaction_import.delete.prompt', [f.leafName]),
                            offlineStrings.getString('main.transaction_import.success'),
                            offlineStrings.getString('common.yes'),
                            offlineStrings.getString('common.no'),
                            null,
                            offlineStrings.getString('common.confirm')
                        );
                        if (r == 0) {
                            f.remove(false);
                        }
                    }
                }
                file.close();
            } catch(E) {
                alert(E);
            }
        };

        G.auth.on_debug = function(action) {
            switch(action) {
                case 'js_console' :
                    G.window.open(urls.XUL_DEBUG_CONSOLE,'testconsole','chrome,resizable');
                break;
                case 'clear_cache' :
                    clear_the_cache();
                    alert(offlineStrings.getString('main.on_debug.clear_cache'));
                break;
                default:
                    alert(offlineStrings.getString('main.on_debug.debug'));
                break;
            }
        };

        G.auth.init();
        // XML_HTTP_SERVER will get reset to G.auth.controller.view.server_prompt.value

        /////////////////////////////////////////////////////////////////////////////

        var version = CLIENT_VERSION;
        if (CLIENT_STAMP.length == 0) {
            version = 'versionless debug build';
            document.getElementById('debug_gb').hidden = false;
        }

        try {
            if (G.pref && G.pref.getBoolPref('open-ils.debug_options')) {
                document.getElementById('debug_gb').hidden = false;
            }
        } catch(E) {
        }

        var appInfo = Components.classes["@mozilla.org/xre/app-info;1"] 
            .getService(Components.interfaces.nsIXULAppInfo); 

        if (appInfo.ID == "staff-client@open-ils.org")
        {
            try {
                if (G.pref && G.pref.getBoolPref('app.update.enabled')) {
                    document.getElementById('check_upgrade_sep').hidden = false;
                    var upgrademenu = document.getElementById('check_upgrade');
                    upgrademenu.hidden = false;
                    G.upgradeCheck = function () {
                        var um = Components.classes["@mozilla.org/updates/update-manager;1"]
                            .getService(Components.interfaces.nsIUpdateManager);
                        var prompter = Components.classes["@mozilla.org/updates/update-prompt;1"]
                            .createInstance(Components.interfaces.nsIUpdatePrompt);

                        if (um.activeUpdate && um.activeUpdate.state == "pending")
                            prompter.showUpdateDownloaded(um.activeUpdate);
                        else
                            prompter.checkForUpdates();
                    }
                    upgrademenu.addEventListener(
                        'command',
                        G.upgradeCheck,
                        false
                    );
                }
            } catch(E) {
            }
        }

        window.title = authStrings.getFormattedString('staff.auth.titlebar.label', version);
        var x = document.getElementById('about_btn');
        x.addEventListener(
            'command',
            function() {
                try { 
                    G.window.open('about.html','about','chrome,resizable,width=800,height=600');
                } catch(E) { alert(E); }
            }, 
            false
        );

        var y = document.getElementById('new_window_btn');
        y.addEventListener(
            'command',
            function() {
                if (G.data.session) {
                    new_tabs(Array('new'), null, null);
                } else {
                    alert ( offlineStrings.getString('main.new_window_btn.login_first_warning') );
                }
            },
            false
        );

        JSAN.use('util.mozilla');
        var z = document.getElementById('locale_menupopup');
        if (z) {
            while (z.lastChild) z.removeChild(z.lastChild);
            var locales = util.mozilla.chromeRegistry().getLocalesForPackage( String( location.href ).split(/\//)[2] );
            var current_locale = util.mozilla.prefs().getCharPref('general.useragent.locale');
            while (locales.hasMore()) {
                var locale = locales.getNext();
                var parts = locale.split(/-/);
                var label;
                try {
                    label = locale + ' : ' + util.mozilla.languages().GetStringFromName(parts[0]);
                    if (parts.length > 1) {
                        try {
                            label += ' (' + util.mozilla.regions().GetStringFromName(parts[1].toLowerCase()) + ')';
                        } catch(E) {
                            label += ' (' + parts[1] + ')';
                        }
                    }
                } catch(E) {
                    label = locale;
                }
                var mi = document.createElement('menuitem');
                mi.setAttribute('label',label);
                mi.setAttribute('value',locale);
                if (locale == current_locale) {
                    if (z.parentNode.tagName == 'menulist') {
                        mi.setAttribute('selected','true');
                        z.parentNode.setAttribute('label',label);
                        z.parentNode.setAttribute('value',locale);
                    }
                }
                z.appendChild( mi );
            }
        }
        var xx = document.getElementById('apply_locale_btn');
        xx.addEventListener(
            'command',
            function() {
                util.mozilla.change_locale(z.parentNode.value);
            },
            false
        );

        if ( found_ws_info_in_Achrome() && G.pref && G.pref.getBoolPref("open-ils.write_in_user_chrome_directory") ) {
            //var hbox = x.parentNode; var b = document.createElement('button'); 
            //b.setAttribute('label','Migrate legacy settings'); hbox.appendChild(b);
            //b.addEventListener(
            //    'command',
            //    function() {
            //        try {
            //            handle_migration();
            //        } catch(E) { alert(E); }
            //    },
            //    false
            //);
            if (window.confirm(offlineStrings.getString('main.settings.migrate'))) {
                setTimeout( function() { handle_migration(); }, 0 );
            }
        }

    } catch(E) {
        var error = offlineStrings.getFormattedString('common.exception', [E, '']);
        try { G.error.sdump('D_ERROR',error); } catch(E) { dump(error); }
        alert(error);
    }
    dump('exiting main_init()\n');
}

function found_ws_info_in_Achrome() {
    JSAN.use('util.file');
    var f = new util.file();
    var f_in_chrome = f.get('ws_info','chrome');
    var path = f_in_chrome.exists() ? f_in_chrome.path : false;
    f.close();
    return path;
}

function found_ws_info_in_Uchrome() {
    JSAN.use('util.file');
    var f = new util.file();
    var f_in_uchrome = f.get('ws_info','uchrome');
    var path = f_in_uchrome.exists() ? f_in_uchrome.path : false;
    f.close();
    return path;
}

function handle_migration() {
    if ( found_ws_info_in_Uchrome() ) {
        alert(offlineStrings.getFormattedString('main.settings.migrate.failed', [found_ws_info_in_Uchrome(), found_ws_info_in_Achrome()])
        );
    } else {
        var dirService = Components.classes["@mozilla.org/file/directory_service;1"].getService( Components.interfaces.nsIProperties );
        var f_new = dirService.get( "UChrm", Components.interfaces.nsIFile );
        var f_old = dirService.get( "AChrom", Components.interfaces.nsIFile );
        f_old.append(myPackageDir); f_old.append("content"); f_old.append("conf"); 
        if (window.confirm(offlineStrings.getFormattedString("main.settings.migrate.confirm", [f_old.path, f_new.path]))) {
            var files = f_old.directoryEntries;
            while (files.hasMoreElements()) {
                var file = files.getNext();
                var file2 = file.QueryInterface( Components.interfaces.nsILocalFile );
                try {
                    file2.moveTo( f_new, '' );
                } catch(E) {
                    alert(offlineStrings.getFormattedString('main.settings.migrate.error', [file2.path, f_new.path]) + '\n');
                }
            }
            location.href = location.href; // huh?
        }
    }
}

dump('exiting main/main.js\n');
