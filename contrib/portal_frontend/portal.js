window.state = {
    module: 'index'
};

riot.route(function(module, id, action) {
    window.state.module = module || 'index';
    window.state.id = id;
    riot.update();
});

riot.route.start();
riot.route(document.location.hash.substr(1));
riot.mount('*', portalOptions);
