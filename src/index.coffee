# Small module to generate vcard file from JS Objects or to parse vcard file
# to obtain explicit JS Objects.
#
# This lib aims to handle parsing of vCards coming from Google Contacts (vCard
# 3.0), Android (vCard 2.1).

if module?.exports # NodeJS
    utf8 = require 'utf8'
    quotedPrintable = require 'quoted-printable'

else #Browser
    utf8 = window.utf8
    quotedPrintable = window.quotedPrintable


regexps =
        begin:       /^BEGIN:VCARD$/i
        end:         /^END:VCARD$/i

        # Some clients (as thunderbird's addon SOGo) may send non VCARD objects.
        beginNonVCard:       /^BEGIN:(.*)$/i
        endNonVCard:         /^END:(.*)$/i

        # vCard 2.1 files can use quoted-printable text.
        simple: /^(version|fn|n|title|org|note|categories|bday|url|nickname|uid)(;CHARSET=UTF-8)?(;ENCODING=QUOTED-PRINTABLE)?\:(.+)$/i
        composedkey: /^item(\d{1,2})\.([^\:]+):(.+)$/
        complex: /^([^\:\;]+);([^\:]+)\:(.+)$/
        property: /^(.+)=(.+)$/
        extended: /^X-([^\:]+)\:(.+)$/i

        # Major vendors exception cases
        applebday: /^(version|fn|n|title|org|note|categories|bday|url);value=date:(.+)$/i
        android: /^x-android-custom\:(.+)$/i


IM_VENDORS = [
    'skype', 'skype-username', 'aim', 'msn', 'yahoo', 'qq',
    'google-talk', 'gtalk', 'icq', 'jabber', 'sip', 'gad'
]

IOS_IM_VENDORS = [
    'aim', 'jabber', 'msn', 'yahoo', 'icq'
]
#item26.IMPP;X-SERVICE-TYPE=GaduGadu:x-apple:gad


PHONETIC_FIELDS = [
    'phonetic-first-name'
    'phonetic-middle-name'
    'phonetic-last-name'
]

ANDROID_RELATIONS = [
    'custom', 'assistant', 'brother', 'child',
    'domestic partner', 'father', 'friend', 'manager', 'mother',
    'parent', 'partner', 'referred by', 'relative', 'sister', 'spouse'
]

BASE_FIELDS = ['fn', 'bday', 'org', 'title', 'url', 'note', 'nickname', 'uid']

SOCIAL_URLS =
    twitter: "http://twitter.com/"
    facebook: "http://facebook.com/"
    flickr: "http://www.flickr.com/photos/"
    linkedin: "http://www.linkedin.com/in/"
    myspace: "http://www.myspace.com/"
    sina: "http://weibo.com/n/"

IOS_SERVICE_TYPES =
    'msn': 'MSN:msnim'
    'skype': 'Skype:skype'
    'google-talk': 'GoogleTalk:xmpp'
    'googletalk': 'GoogleTalk:xmpp'
    'gtalk': 'GoogleTalk:xmpp'
    'facebook': 'Facebook:xmpp'
    'aim': 'AIM:aim'
    'yahoo': 'Yahoo:aim'
    'icq': 'ICQ:aim'
    'jabber': 'Jabber:xmpp'
    'qq': 'QQ:x-apple'
    'gadugadu': 'GaduGadu:x-apple'

IOS_SERVICE_LABELS =
    'msn': 'MSN'
    'skype': 'Skype'
    'google-talk': 'GoogleTalk'
    'googletalk': 'GoogleTalk'
    'gtalk': 'GoogleTalk'
    'facebook': 'Facebook'
    'aim': 'AIM'
    'yahoo': 'Yahoo:'
    'icq': 'ICQ'
    'jabber': 'Jabber'
    'qq': 'QQ'
    'gadugadu': 'GaduGadu'


isValidDate = (date) ->
    matches = /^(\d{4})[-\/](\d{2})[-\/](\d{2})$/.exec date
    if matches is null
        false
    else
        y = parseInt matches[1]
        m = parseInt matches[2] - 1
        d = parseInt matches[3]
        date = new Date y, m, d

        res = date.getDate() is d
        res = res and date.getMonth() is m
        res = res and date.getFullYear() is y
        res


capitalizeFirstLetter = (string) ->
    "#{string.charAt(0).toUpperCase()}#{string.toLowerCase().slice(1)}"


getAndroidItem = (type, key, value) ->

    key = key.toLowerCase().replace '_', ' '
    if key is 'anniversary'
        index = 1
    else if key is 'died'
        index = 2
    else
        index = 0
        length = ANDROID_RELATIONS.length
        index++ while index < length and ANDROID_RELATIONS[index] isnt key
        key = null if index is length

    if key
        prefix = 'X-ANDROID-CUSTOM:vnd.android.cursor.item/'
        "#{prefix}#{type};#{value};#{index};;;;;;;;;;;;;"
    else
        null


# The arser will read all data from the vcard and generate a Cozy contact
# object from it.
class VCardParser


    constructor: (vcf) ->
        @reset()
        @read vcf if vcf


    # Clear all generated contacts.
    reset: ->
        @contacts         = []
        @currentContact   = null
        @currentDatapoint = null
        @currentIndex     = null
        @currentVersion   = "3.0"


    storeCurrentDatapoint: ->
        if @currentDatapoint
            @currentContact.datapoints.push @currentDatapoint
            @currentDatapoint = null


    addDatapoint: (name, type, value) ->
        @storeCurrentDatapoint()
        @currentContact.datapoints.push {name, type, value}


    # Google, iOS use many type fields.
    # We decide home, work, cell have priotiry over others.
    addTypeProperty: (dp, pvalue) ->
        if dp.type? and dp.type isnt 'internet'
            dp.type = "#{dp.type} #{pvalue}"

        else
            dp.type = pvalue


    storeCurrentContact: ->
        # There is two fields N and FN that does the same thing but not the
        # same way. Some vCard have one or ther other, or both.
        # If both are present, we keep them.
        # If only one is present, we compute the other one.
        if not @currentContact.n? and not @currentContact.fn?
            console.error 'There should be at least a N field or a FN field'

        if (not @currentContact.n?) or @currentContact.n in ['', ';;;;']
            @currentContact.n = VCardParser.fnToN(@currentContact.fn).join ';'

        if (not @currentContact.fn?) or @currentContact.fn is ''
            @currentContact.fn = VCardParser.nToFN @currentContact.n

        @contacts.push @currentContact


    # Parse vcard and put generated contacts in the contacts field.
    read: (vcard) ->
        @handleLine line for line in @splitLines vcard


    # Split vCard in clean lines.
    # unfold folded fields (like photo)
    # some vCard 2.1 files use = at end of quoted-printable lines
    # instead of space at start of next line.
    splitLines: (vcard) ->
        sourcelines = vcard.split /\r?\n/
        lines = []

        inQuotedPrintable = false

        sourcelines.forEach (line) ->

            # skip empty lines.
            unless (not line?) or line is ''

                # Unfold cases
                if line[0] is ' ' or inQuotedPrintable

                    # Unfold lines which starts with ' '
                    if line[0] is ' '
                        line = line[1..]

                    if inQuotedPrintable
                        if line[line.length - 1] is '='
                            line = line.slice 0, -1
                        else
                            inQuotedPrintable = false

                    lineIndex = lines.length - 1

                    if lineIndex >= 0
                        lines[lineIndex] = lines[lineIndex] + line
                    else
                        lines.push line

                else

                    if /^(.+)ENCODING=QUOTED-PRINTABLE(.+)=$/i.test line
                        inQuotedPrintable = true
                        line = line.slice 0, -1

                    lines.push line

        return lines


    # Parse a given line. Match it with every know regexp that could possibly
    # be found in a vcard. Then add corresponding properties to the generated
    # contact.
    handleLine: (line) ->
        if @nonVCard
            if regexps.endNonVCard.test line
                if line.match(regexps.endNonVCard)[1] is @nonVCard
                    @nonVCard = false

            # else ignore current line up to END:@nonVCard .

        # Here we have a new contact to parse.
        else if regexps.begin.test line
            @currentContact = datapoints: []

        # Here we detect vCards that don't follow the right format.
        else if regexps.beginNonVCard.test line
            @nonVCard = line.match(regexps.beginNonVCard)[1]

        # Here is the termination of a contact description.
        else if regexps.end.test line
            @storeCurrentDatapoint()
            @storeCurrentContact()

        else if regexps.simple.test line
            @handleSimpleLine line

        else if regexps.applebday.test line
            @handleSimpleLine line, true

        else if regexps.android.test line
            @handleAndroidLine line

        else if regexps.extended.test line
            @handleExtendedLine line

        else if regexps.composedkey.test line
            @handleComposedLine line

        else if regexps.complex.test line
            @handleComplexLine line


    # handle easy lines such as TITLE:XXX
    # Those lines are often basic fields.
    handleSimpleLine: (line, apple=false) ->

        # Apple Bday has a special syntax.
        if apple
            [all, key, value] = line.match regexps.applebday
        else
            [all, key, utf, quoted, value] = line.match regexps.simple

        # Extract and apply unquoted and unescape parameters.
        value = VCardParser.unquotePrintable value if quoted?
        value = VCardParser.unescapeText value

        # Make all key lowercase to simplify processing.
        key = key.toLowerCase()

        # Extract vcard formatting version.
        if key is 'version'
            @currentversion = value

        else if key is 'rev'
            @currentContact.revision = value

        # Extract categories as tags. They are similare concepts.
        else if key is 'categories'
            @currentContact.tags = value.split /(?!\\),/
                                        .map VCardParser.unescapeText

        # Build name from n field.
        else if key is 'n'

            # assert 5 fields, separated by ';'
            nParts = value.split /(?!\\);/
            if nParts.length is 5
                @currentContact['n'] = value

            else
                nPartsCleaned = ['', '', '', '', '']

                if nParts.length < 5
                    nParts.forEach (part, index) -> nPartsCleaned[index] = part

                else # if too much fields, merge everything in firstname.
                    nPartsCleaned[2] = nParts.join ' '

                @currentContact['n'] = nPartsCleaned.join ';'


        # Direct field attached directly to the datapoint object.
        else if key in BASE_FIELDS

            # Ios include department in the org field (company;department)
            if key is 'org'
                values = value.split ';'

                if values.length is 2
                    @currentContact.org = values[0]
                    @currentContact.department = values[1]
                else
                    @currentContact.org = value

            else
                @currentContact[key.toLowerCase()] = value


    # Handle X- fields like (called extended fields by the RFC, those one are
    # not standards):
    # X-SKYPE: myskype
    # It changes depending on vcard vendors, so that funcs handle many specific
    # cases.
    handleExtendedLine: (line) ->
        [all, key, value] = line.match regexps.extended

        if key?
            key = key.toLowerCase()

            if key in IM_VENDORS
                @currentContact.datapoints.push
                    name: 'chat', type: key, value: value

            else if key in PHONETIC_FIELDS
                key = key.replace(/-/g, ' ')
                @currentContact.datapoints.push
                    name: 'about', type: key, value: value

            # iOS way to store social profiles
            else if key.indexOf('socialprofile') is 0
                elements = key.split(';')
                if elements.length > 2
                    type = elements[1].split('=')[1]
                    user = elements[2].split('=')[1]
                    @currentContact.datapoints.push
                        name: 'social', type: type, value: user

            # Storea activity alert information. Do not try to format them.
            # It's essentially useful to not lose that data during sync
            # with iOS devices.
            else if key is 'activity-alert'
                vals = value.split ','
                if vals.length > 1
                    type = vals.splice(0, 1)[0]
                    type = type.split('=')[1].replace /\\/g, ''
                    value = vals.join ','
                @currentContact.datapoints.push
                    name: 'alerts', type: type, value: value


    # handle android-android lines of which type starts with
    # vnd.android.cursor.item/
    handleAndroidLine: (line) ->

        [all, raw] = line.match regexps.android
        parts = raw.split ';'

        switch parts[0].replace 'vnd.android.cursor.item/', ''

            when 'contact_event'
                value = parts[1]
                # Android provide only number to give the event type.
                type = if parts[2] in ['0', '2'] then parts[3]
                else if parts[2] is '1' then 'anniversary'
                else 'birthday'
                @currentContact.datapoints.push
                    name: 'about', type: type, value: value

            when 'relation'
                value = parts[1]
                # Android provide only number to give the relation type.
                type = ANDROID_RELATIONS[+parts[2]]
                type = parts[3] if type is 'custom'
                @currentContact.datapoints.push
                    name: 'relation', type: type, value: value

            when 'nickname'
                value = parts[1]
                @currentContact.nickname = value


    handleCurrentSpecialCases: ->
        dp = @currentDatapoint

        # iOS case for instant messaging accounts
        if dp?.type in IM_VENDORS
            dp.name = 'chat'
            if dp['x-service-type']?
                dp.value = dp.value.split(':')[1]

                if dp['x-service-type'] not in IM_VENDORS
                    dp.type = dp['x-service-type']

        # iOS case for instant messaging accounts
        if dp?.name is 'impp'
            dp.name = 'chat'
            dp.value = dp.value.split(':')[1]


    # Handle multi-lines Data Points (custom label)
    # When there are several lines, the datapoint is temporarly stored to
    # be processed after.
    handleComposedLine: (line) ->
        [all, itemidx, part, value] = line.match regexps.composedkey

        if @currentIndex is null or @currentIndex isnt itemidx
            @handleCurrentSpecialCases()
            @storeCurrentDatapoint()
            @currentDatapoint = {}

        @currentIndex = itemidx

        part = part.split ';'
        key = part[0]
        properties = part.splice 1

        value = value.split ';'

        if value.length is 1
            value = value[0].replace('_$!<', '')
            .replace('>!$_', '').replace('\\:', ':')

        key = key.toLowerCase()

        if key is 'x-ablabel' or key is 'x-abadr'
            @addTypeProperty @currentDatapoint, value.toLowerCase()

        else
            @handleProperties @currentDatapoint, properties

            if key is 'x-abdate'
                key = 'about'

            if key is 'x-abrelatednames'
                key = 'relation'

            if key is 'adr'
                if Array.isArray value
                    value = value.map VCardParser.unescapeText
                else
                    value = ['', '', VCardParser.unescapeText(value),
                    '', '', '', '']

            @currentDatapoint['name'] = key.toLowerCase()
            @currentDatapoint['value'] = value


    # Complex lines has several types.
    handleComplexLine: (line) ->
        [all, key, properties, value] = line.match regexps.complex

        @storeCurrentDatapoint()
        @currentDatapoint = {}

        value = value.split ';'
        value = value[0] if value.length is 1

        key = key.toLowerCase()

        if key is 'photo'
            # photo is a special field, not marked as a datapoint
            @currentContact['photo'] = value
            @currentDatapoint = null

        else if not key in ['email', 'tel', 'adr', 'url']

            #@TODO handle unkwnown keys
            @currentDatapoint = null

        else
            @currentDatapoint['name'] = key
            if key is 'adr'
                if Array.isArray value

                    value = value.map VCardParser.unescapeText
                else
                    value = ['', '', VCardParser.unescapeText(value),
                    '', '', '', '']

            @handleProperties @currentDatapoint, properties.split ';'

            if @currentDatapoint.encoding is 'quoted-printable'
                if Array.isArray value
                    value = value.map VCardParser.unquotePrintable
                else
                    value = VCardParser.unquotePrintable value
                delete @currentDatapoint.encoding

            @currentDatapoint.value = value


    handleProperties : (dp, properties) ->
        for property in properties

            # property is XXX=YYYY
            if match = property.match regexps.property
                [all, pname, pvalue] = match

                # Handles case where the same property is declared twice like
                # in:
                # TYPE="work";TYPE="fax"
                pvalue = pvalue.toLowerCase()
                #pvalue = 'home' if pvalue is 'internet'

                previousValue = dp[pname.toLowerCase()]
                # Google export email with type internet
                if previousValue? and previousValue isnt 'internet'
                    pvalue = "#{previousValue} #{pvalue}"

            else if property is 'PREF'
                pname = 'pref'
                pvalue = true

                if dp.type?
                    dp.type = "#{dp.type} #{property.toLowerCase()}"
                else
                    dp.type = property.toLowerCase()

            else
                pname = 'type'

                if dp.type?
                    pvalue = "#{dp.type} #{property.toLowerCase()}"
                else
                    pvalue = property.toLowerCase()

            # iOS use type=pref instead of pref=123.
            if pname is 'type' and pvalue is 'pref'
                pname = 'pref'
                pvalue = true

            dp[pname.toLowerCase()] = pvalue


# Decode to UTF-8 given string.
VCardParser.unquotePrintable = (value) ->
    value = value or ''
    try
        return utf8.decode quotedPrintable.decode value
    catch error
        # Error decoding,
        return value


# Add \ before special chars.
VCardParser.escapeText = (value) ->
    if not value?
        return value
    else
        text = value.replace /([,;\\])/ig, "\\$1"
        text = text.replace /\n/g, '\\n'
        return text


# Remove \ before special chars.
VCardParser.unescapeText = (t) ->
    if not t?
        return t
    else
        s = t.replace /\\n/ig, '\n'
        s = s.replace /\\([,;\\])/ig, "$1"
        return s


# Export contact model to a VCF card. We try here to follow the Google Contacts
# convention. Despite, there is no clear way about how to properly build
# vCards.
VCardParser.toVCF = (model, picture = null, mode = 'google') ->

    itemCounter = 0 # Required to add number to non standard items.
    out = ["BEGIN:VCARD"] # Out will contain all the vcard lines.
    out.push "VERSION:3.0" # Version of the created vCard.

    exportUid out, model
    exportRev out, model if model.revision?
    exportName out, model if model.n?
    exportBaseFields out, model
    exportTags out, model if model.tags? and model.tags.length > 0

    # Handle datapoints and special cases.
    for i, datapoint of model.datapoints
        continue unless datapoint.name? and datapoint.value?
        key = datapoint.name.toUpperCase()
        type = datapoint.type?.toUpperCase() or null
        value = datapoint.value

        if Array.isArray value
            value = value.map VCardParser.escapeText
        else
            value = VCardParser.escapeText value

        formattedType = ""
        if type?
            types = type.split ' '
            formattedType += ";TYPE=#{currentType}" for currentType in types

        options = {
            out, type, formattedType, value, mode, itemCounter, key
        }
        switch key

            when 'ABOUT'
                itemCounter = exportAbout options
            when 'OTHER'
                itemCounter = exportOther options
            when 'CHAT'
                itemCounter = exportChat options
            when 'URL'
                itemCounter = exportUrl options
            when 'RELATION'
                itemCounter = exportRelation options
            when 'ADR'
                itemCounter = exportAdr options
            when 'SOCIAL'
                itemCounter = exportSocial options
            when 'ALERTS'
                itemCounter = exportAlerts options
            else
                itemCounter = exportDefault options

    # Handle picture field.
    # TODO: handle URI pictures
    exportPicture out, picture if picture?

    # Close the vcard and build the result string.
    out.push "END:VCARD"
    return out.join("\n") + "\n"


# Generates unique id.
exportUid = (out, model) ->
    uri = model.carddavuri
    uid = uri?.substring(0, uri.length - 4) or model.id
    out.push "UID:#{uid}" if uid?


# Base fields, simple with no extra attributes.
exportBaseFields = (out, model) ->
    for prop in BASE_FIELDS
        value = model[prop]
        value = VCardParser.escapeText value if value

        # Org is a special because it may includes the department.
        if prop is 'org'
            if model.department? and model.department.length > 0
                department = VCardParser.escapeText model.department
                value = "#{value};#{department}"

        out.push "#{prop.toUpperCase()}:#{value}" if value


# Name fields is already ready to export.
exportName = (out, model) ->
    out.push "N:#{model.n}"


# Date of last change at ISO format.
exportRev = (out, model) ->
    if typeof(model.revision) is 'date'
        out.push "REV:#{model.revision.toISOString()}"
    else
        out.push "REV:#{model.revision}"


# Handles tags/categories/groups.
exportTags = (out, model) ->
    value = model.tags.map(VCardParser.escapeText).join ','
    out.push "CATEGORIES:#{value}"


# About contains mainly phonetic fields and date fields.
# Android requires weird format.
# It the type of the field is not known.
exportAbout = (options) ->
    {out, type, formattedType, value, mode, itemCounter} = options

    # Android handles it in a specific manner.
    if type in ['DIED', 'ANNIVERSARY']

        if mode is 'android'
            out.push getAndroidItem 'contact_event', type, value

        else
            itemCounter++
            out.push "item#{itemCounter}.X-ABDATE:#{value}"
            formattedType = capitalizeFirstLetter type
            out.push "item#{itemCounter}.X-ABLabel:#{formattedType}"

    # For Phonetic fields, hyphens should be added back
    else if type.indexOf('PHONETIC') is 0
        out.push "X-#{type.replace(/\s/g, '-')}:#{value}"

    # Check if it's a date. In that case an ABDATE field should be created.
    else if isValidDate value
        itemCounter++
        out.push "item#{itemCounter}.X-ABDATE:#{value}"
        formattedType = capitalizeFirstLetter type
        out.push "item#{itemCounter}.X-ABLabel:#{formattedType}"

    # Create an extended field for this type.
    else
        out.push "X-#{type}:#{value}"

    return itemCounter


# All other fields are treated as extended events.
# TODO: find something proper.
exportOther = (options) ->
    {out, type, formattedType, value, mode, itemCounter} = options
    out.push "X-EVENT#{formattedType}:#{value}"

    return itemCounter


# Chat fields are traditional extended fields.
# iOS requires a weird format with predefined string depending on the im
# vendor.
exportChat = (options) ->
    {out, type, formattedType, value, mode, itemCounter} = options

    # Android don't know skype, it only knows skype-username.
    if type is 'SKYPE' and mode is 'android'
        out.push "X-SKYPE-USERNAME:#{value}"

    else

        if mode is 'ios'
            itemCounter++

            serviceType = IOS_SERVICE_TYPES[type.toLowerCase()]
            if serviceType?
                line = "item#{itemCounter}.IMPP;"
                line += "X-SERVICE-TYPE=#{serviceType}:#{value}"
                out.push line

            else
                type = capitalizeFirstLetter type.toLowerCase()
                line = "item#{itemCounter}.IMPP;"
                line += "X-SERVICE-TYPE=#{type}:x-apple:#{value}"
                out.push line

        else
            out.push "X-#{type}:#{value}"

    return itemCounter


# URL generates item line. It handles specific case for
# PROFILE and BLOG types.
exportUrl = (options) ->
    {out, type, formattedType, value, mode, itemCounter} = options

    if type?
        itemCounter++
        out.push "item#{itemCounter}.URL:#{value}"
        if type not in ['PROFILE', 'BLOG']
            formattedType = capitalizeFirstLetter type.toLowerCase()
            if (mode is 'ios') and type in ['HOME', 'WORK', 'OTHER']
                out.push "item#{itemCounter}.X-ABLabel:_$!<#{formattedType}>!$_"
            else if mode is 'ios'
                out.push "item#{itemCounter}.X-ABLabel:#{formattedType}"
            else
                out.push "item#{itemCounter}.X-ABLabel:_$!<#{formattedType}>!$_"

        else
            out.push "item#{itemCounter}.X-ABLabel:#{type}"
    else
        out.push "URL:#{value}"

    return itemCounter


# Relations generates item line.
# Android required a weird format.
exportRelation = (options) ->
    {out, type, formattedType, value, mode, itemCounter} = options

    if mode is 'android'
        line = getAndroidItem 'relation', type, value
        out.push line if line

    else
        itemCounter++
        out.push "item#{itemCounter}.X-ABRELATEDNAMES:#{value}"
        formattedType = capitalizeFirstLetter type.toLowerCase()
        out.push "item#{itemCounter}.X-ABLabel:_$!<#{formattedType}>!$_"

    return itemCounter


# Standard address field  with type metadata.
exportAdr = (options) ->
    {out, type, formattedType, value, mode, itemCounter, key} = options

    out.push "#{key}#{formattedType}:#{value.join ';'}"

    return itemCounter


# Here we export social profile the same way iOS does.
# https://tools.ietf.org/html/draft-george-vcarddav-vcard-extension-03
exportSocial = (options) ->
    {out, type, formattedType, value, mode, itemCounter, key} = options

    url = value
    urlPrefix = SOCIAL_URLS[type.toLowerCase()]
    if urlPrefix?
        url = "#{urlPrefix}#{value}"
    else
        formattedType = capitalizeFirstLetter type.toLowerCase()
        formattedType = ";TYPE=#{formattedType}"

    res = "X-SOCIALPROFILE#{formattedType};x-user=#{value}:#{url}"
    out.push res

    return itemCounter


# Export alerts in the weird iOS format. Clean \\\ that can become
# too numerous.
exportAlerts = (options) ->
    {out, type, formattedType, value, mode, itemCounter, key} = options

    type = type.toLowerCase()
    value = value.replace /\\\\\\/g, "\\"
    res = "X-ACTIVITY-ALERT:type=#{type}\\,#{value}"
    out.push res

    return itemCounter


# We don't know this kind of field, just add it as a complex field.
exportDefault = (options) ->
    {out, type, formattedType, value, mode, itemCounter, key} = options

    out.push "#{key}#{formattedType}:#{value}"

    return itemCounter


# vCard 3.0 specifies that lines must be folded at 75 characters
# with "\n " as a delimiter
exportPicture = (out, picture) ->
    folded = picture.match(/.{1,75}/g).join '\n '
    pictureString = "PHOTO;ENCODING=B;TYPE=JPEG;VALUE=BINARY:\n #{folded}"
    out.push pictureString


##
# Tools for VCard instances.
##
# With this Model :
# - fn: String # vCard FullName = display name
#   (Prefix Given Middle Familly Suffix)
# - n: [String] # vCard Name = splitted
#   [Familly, Given, Middle, Prefix, Suffix]
VCardParser.nToFN = (n) ->
    n = n or []

    [familly, given, middle, prefix, suffix] = n

    # order parts of name.
    parts = [prefix, given, middle, familly, suffix]
    # remove empty parts
    parts = parts.filter (part) -> part? and part isnt ''

    return parts.join ' '


# Put fn as n's firstname.
VCardParser.fnToN = (fn) ->
    fn = fn or ''

    return ['', fn, '', '', '']


# Parse n field from fn, trying to fill in firstname, lastname and middlename.
VCardParser.fnToNLastnameNFirstname = (fn) ->
    fn = fn or ''

    [given, middle..., familly] = fn.split ' '
    parts = [familly, given, middle.join(' '), '', '']

    return parts


# Convert splitted vCard address format, to flat one, but with line breaks.
# @param value expect an array (adr value, splitted by ';').
VCardParser.adrArrayToString = (value) ->
    # UX is partly broken on iOS with adr on more than 2 lines.
    # So, we convert structured address to 2 lines flat address,
    # First: Postbox, appartment and street adress on first (field: 0, 1, 2)
    # Second: Locality, region, postcode, country (field: 3, 4, 5, 6)
    value = value or []

    structuredToFlat = (t) ->
        t = t.filter (part) -> return part? and part isnt ''
        return t.join ', '

    streetPart = structuredToFlat value[0..2]
    countryPart = structuredToFlat value[3..6]

    flat = streetPart
    flat += '\n' + countryPart if countryPart isnt ''
    return flat


# Convert String (of an address) to a [String][7]
VCardParser.adrStringToArray = (s) ->
    s = s or ''
    return ['', '', s, '', '', '', '']


if module?.exports
    module.exports = VCardParser
else
    window.VCardParser = VCardParser
