fx_version 'cerulean'
game 'common'

author 'OpenAI for user'
description 'PRP styled chat with dark OOC bars and yellow invalid command alerts'
version '1.4.0'

dependency 'chat'

file 'style.css'
file 'shadow.js'

chat_theme 'gtao' {
    styleSheet = 'style.css',
    script = 'shadow.js',
    msgTemplates = {
        default = [[
            <div class="prp-msg prp-default" data-author="{0}" data-template="default">
                <div class="prp-icon">💬</div>
                <div class="prp-body">
                    <div class="prp-header">{0}</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]],

        ooc = [[
            <div class="prp-msg prp-ooc" data-author="{0}" data-template="ooc">
                <div class="prp-icon">🗨️</div>
                <div class="prp-body">
                    <div class="prp-header">[OOC] {0}</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]],

        system = [[
            <div class="prp-msg prp-system" data-author="SERVER" data-template="system">
                <div class="prp-icon">⚠️</div>
                <div class="prp-body">
                    <div class="prp-header">SERVER</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]],

        invalidcmd = [[
            <div class="prp-msg prp-invalid" data-author="SERVER" data-template="invalidcmd">
                <div class="prp-icon">⚠️</div>
                <div class="prp-body">
                    <div class="prp-header">SERVER</div>
                    <div class="prp-text">Invalid Command</div>
                </div>
            </div>
        ]],

        admin = [[
            <div class="prp-msg prp-admin" data-author="{0}" data-template="admin">
                <div class="prp-icon">🛡️</div>
                <div class="prp-body">
                    <div class="prp-header">{0}</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]],

        police = [[
            <div class="prp-msg prp-police" data-author="{0}" data-template="police">
                <div class="prp-icon">🚓</div>
                <div class="prp-body">
                    <div class="prp-header">{0}</div>
                    <div class="prp-text">{1}</div>
                </div>
            </div>
        ]]
    }
}
