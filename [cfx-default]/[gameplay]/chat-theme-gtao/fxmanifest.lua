fx_version 'cerulean'
game 'common'

author 'PRP'
description 'PRP styled chat bubbles with colored system and resource messages'
version '1.5.0'

dependency 'chat'

file 'style.css'
file 'shadow.js'

chat_theme 'gtao' {
    styleSheet = 'style.css',
    script = 'shadow.js',
    msgTemplates = {
        default = [[
            <div class="prp-msg prp-default">
                <div class="prp-icon">CHAT</div>
                <div class="prp-body">
                    <div class="prp-header">{0}</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]],

        ooc = [[
            <div class="prp-msg prp-ooc">
                <div class="prp-icon">OOC</div>
                <div class="prp-body">
                    <div class="prp-header">[OOC] {0}</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]],

        system = [[
            <div class="prp-msg prp-system">
                <div class="prp-icon">SYS</div>
                <div class="prp-body">
                    <div class="prp-header">SERVER</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]],

        resource = [[
            <div class="prp-msg prp-resource">
                <div class="prp-icon">RES</div>
                <div class="prp-body">
                    <div class="prp-header">RESOURCE</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]],

        invalidcmd = [[
            <div class="prp-msg prp-invalid">
                <div class="prp-icon">ERR</div>
                <div class="prp-body">
                    <div class="prp-header">SERVER</div>
                    <div class="prp-text">Invalid Command</div>
                </div>
            </div>
        ]],

        admin = [[
            <div class="prp-msg prp-admin">
                <div class="prp-icon">ADM</div>
                <div class="prp-body">
                    <div class="prp-header">{0}</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]],

        police = [[
            <div class="prp-msg prp-police">
                <div class="prp-icon">PD</div>
                <div class="prp-body">
                    <div class="prp-header">{0}</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]]
    }
}
