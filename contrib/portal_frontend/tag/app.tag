<!-- helper tag that renders a markdown page. -->
<markdown-page>
    <div class="markdown-render">
    </div>

    this.on('mount', function() {
        var el = this.root;
        promise.get('pages/' + opts.page + '.md')
        .then(function(error, text, xhr) {
            el.querySelector("div.markdown-render").innerHTML = marked(text);
        });
    });
</markdown-page>

<top-navbar>
    <div class="navbar navbar-default">
        <div class="container">
            <div class="navbar-header">
                <a href="#" class="navbar-brand">{ opts.title }</a>
            </div>
            <div id="navbar-main" class="navbar-collapse collapse">
                <ul class="nav navbar-nav">
                    <li each={ opts.links }>
                        <a if={ url } href={ url } target="_blank">{ name }</a>
                        <a if={ page } href="#page/{ page }">{ name }</a>
                    </li>
                </ul>
                <ul class="nav navbar-nav navbar-right">
                    <li><a href="#users/new">Sign up</a></li>
                </ul>
            </div>
        </div>
    </div>

    this.on('mount', function() {
        document.title = this.opts.title;
    });
</top-navbar>

<sign-in>
    <div class="panel panel-default">
        <div class="panel-heading">Sign in to manage your keys</div>
        <div class="panel-body">
            <form>
                <div class="form-group">
                    <label>Your email</label>
                    <input type="email" class="form-control" placeholder="you@yourdomain.com">
                </div>
                <div class="form-group">
                    <label>
                        Password
                    </label>
                    <input type="password" class="form-control">
                </div>
                <div>
                    <button class="btn btn-primary" type="submit">Sign in</button>
                    <a class="small pull-right" onclick={ parent.toggleForgot } href="#">Forgot your password?</a>
                </div>
            </form>
            <hr>
            Don't have an account? <a href="#">Sign up.</a>
        </div>
    </div>
</sign-in>

<forgot-password>
    <div class="panel panel-default">
        <div class="panel-heading">Reset your password</div>
        <div class="panel-body">
            <p>A password reset link will be sent to your email.</p>
            <form>
                <div class="form-group">
                    <label>Your email</label>
                    <input type="email" class="form-control" placeholder="you@yourdomain.com">
                </div>
                <div>
                    <button class="btn btn-primary" type="submit">Send link</button>
                </div>
            </form>
            <hr>
            Nevermind, <a href="#" onclick={ parent.toggleForgot }>go back to sign in.</a>
        </div>
    </div>
</forgot-password>

<!-- the index page. -->
<index-page>
    <div class="row">
        <div class="col-md-8">
            <markdown-page page="index">
        </div>
        <div class="col-md-4">
            <sign-in if={ !forgot }></sign-in>
            <forgot-password if={ forgot }></forgot-password>
        </div>
    </div>

    this.forgot = false;

    toggleForgot(e) {
        this.forgot = !this.forgot;
        this.update();
    };

</index-page>

<!-- main portal app, does routing etc. -->
<portal-app>
    <div class="container">
        <markdown-page if={ state.module === 'page' } page={ state.id }></markdown-page>
        <index-page if={ state.module === 'index' }></index-page>
    </div>
</portal-app>
