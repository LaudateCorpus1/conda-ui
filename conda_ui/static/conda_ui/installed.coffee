define [
    "underscore"
    "jquery"
    "backbone"
    "ractive"
    "conda_ui/package_actions_bar"
], (_, $, Backbone, Ractive, PackageActionsBar) ->

    class InstalledView extends Backbone.View

        initialize: (options) ->
            super(options)
            @envs = options.envs
            @pkgs = options.pkgs

            @loading = @$('.loading')
            @updates = []

            @ractive = new Ractive({
                el: @el,
                template: '#template-package-table',
                data: {
                    pkgs: []
                }
            })
            @ractive.on 'select', @on_check

            @listenTo(@envs, 'sync', () => @render(); @update())
            @listenTo(@pkgs, 'sync', () => @render())
            @listenTo(@envs, 'activate', () => @render())
            @listenTo(@pkgs, 'filter', () => @render())

        update: () ->
            env = @envs.get_active()
            if not env? then return
            # Have conda figure out what needs updating
            env.attributes.update({
                dryRun: true
                useLocal: true
                all: true
            }).then (data) =>
                if data.success? and data.success
                    updates = data.actions.LINK
                    @updates = updates.map (cmd) ->
                        pkg = cmd.split(" ")[0]
                        parts = pkg.split(/-/g)
                        return parts.slice(0, -2).join('-')
                else
                    @updates = []

                @render()

        render: () ->
            env = @envs.get_active()
            if not env? then return

            installed = env.get('installed')

            pkgs = for own name, info of installed
                info = info.info
                if not info.channel?
                    info.channel = '<no channel>'
                if not info.features?
                    info.features = []
                info

            pkgs = _.sortBy(pkgs, (pkg) -> pkg.name)

            @installed = for pkg in pkgs
                if @pkgs.do_filter(pkg.name)
                    continue

                {
                    name: pkg.name,
                    version: pkg.version,
                    build: pkg.build,
                    channel: pkg.canonical_channel or pkg.channel,
                    features: if pkg.features.length > 0 then pkg.features.join(", ") else "&mdash;",
                    update: @updates.indexOf(pkg.name) > -1
                }

            @ractive.reset { pkgs: @installed }
            @loading.hide()

        on_check: (event) =>
            pkg = $(event.node).parent().next().data('package-name')
            checked = $(event.node).prop('checked')
            PackageActionsBar.instance().setMode('installed')
            PackageActionsBar.instance().on_check(pkg, checked)

    return {View: InstalledView}
