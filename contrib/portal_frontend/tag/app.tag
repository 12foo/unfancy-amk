<top-navbar>
    <div class="navbar navbar-default navbar-fixed-top">
        <div class="container">
            <div class="navbar-header">
                <a class="navbar-brand">{ opts.portalTitle }</a>
            </div>
            <div id="navbar-main" class="navbar-collapse collapse">
                <ul class="nav navbar-nav navbar-right">
                    <li><a href="#/users/new">Sign Up</a></li>
                </ul>
            </div>
        </div>
    </div>

    this.on('mount', function() {
        document.title = this.opts.portalTitle;
    });
</top-navbar>

<portal-app>
</portal-app>
