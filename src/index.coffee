# Small module to generate vcard file from JS Objects or to parse vcard file
# to obtain explicit JS Objects.

if module?.exports # NodeJS
    utf8 = require 'utf8'
    quotedPrintable = require 'quoted-printable'

else #Browser
    utf8 = window.utf8
    quotedPrintable = window.quotedPrintable

# Parser inspired by https://github.com/mattt/vcard.js

regexps =
        begin:       /^BEGIN:VCARD$/i
        end:         /^END:VCARD$/i
        # vCard 2.1 files can use quoted-printable text.
        simple:     /^(version|fn|n|title|org|note)(;CHARSET=UTF-8)?(;ENCODING=QUOTED-PRINTABLE)?\:(.+)$/i
        android:     /^x-android-custom\:(.+)$/i
        composedkey: /^item(\d{1,2})\.([^\:]+):(.+)$/
        complex:     /^([^\:\;]+);([^\:]+)\:(.+)$/
        property:    /^(.+)=(.+)$/

ANDROID_RELATION_TYPES = ['custom', 'assistant', 'brother', 'child',
            'domestic partner', 'father', 'friend', 'manager', 'mother',
            'parent', 'partner', 'referred by', 'relative', 'sister', 'spouse']

class VCardParser

    constructor: (vcf) ->
        @reset()
        @read vcf if vcf

    reset: ->
        @contacts         = []
        @currentContact   = null
        @currentDatapoint = null
        @currentIndex     = null
        @currentVersion   = "3.0"

    read: (vcf) ->
        @handleLine line for line in @splitLines vcf

    # unfold folded fields (like photo)
    # some vCard 2.1 files use = at end of quoted-printable lines
    # instead of space at start of next line.
    splitLines: (s) ->
        sourcelines = s.split /\r?\n/
        lines = []

        inQuotedPrintable = false

        sourcelines.forEach (line) ->
            if (not line?) or line is ''
                return # skip empty lines.

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


    handleLine: (line) ->
        if regexps.begin.test line
            @currentContact = {datapoints:[]}

        else if regexps.end.test line
            @storeCurrentDatapoint()
            @storeCurrentContact()

        else if regexps.simple.test line
            @handleSimpleLine line

        else if regexps.android.test line
            @handleAndroidLine line

        else if regexps.composedkey.test line
            @handleComposedLine line

        else if regexps.complex.test line
            @handleComplexLine line

    storeCurrentDatapoint: ->
        if @currentDatapoint
            @currentContact.datapoints.push @currentDatapoint
            @currentDatapoint = null

    addDatapoint: (name, type, value) ->
        @storeCurrentDatapoint()
        @currentContact.datapoints.push {name, type, value}

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


    # handle easy lines such as TITLE:XXX
    handleSimpleLine: (line) ->
        [all, key, utf, quoted, value] = line.match regexps.simple
        if quoted?
            value = VCardParser.unquotePrintable value
        value = VCardParser.unescapeText value

        if key is 'VERSION'
            return @currentversion = value

        else if key in ['TITLE', 'ORG', 'FN', 'NOTE', 'N', 'BDAY']
            return @currentContact[key.toLowerCase()] = value

    # handle android-android lines (cursor.item)
    #@TODO support other possible cursors
    handleAndroidLine: (line) ->
        [all, raw] = line.match regexps.android
        parts = raw.split ';'
        switch parts[0].replace 'vnd.android.cursor.item/', ''
            when 'contact_event'
                value = parts[1]
                type = if parts[2] in ['0', '2'] then parts[3]
                else if parts[2] is '1' then 'anniversary'
                else 'birthday'
                @currentContact.datapoints.push
                    name: 'about', type: type, value: value
            when 'relation'
                value = parts[1]
                type = ANDROID_RELATION_TYPES[+parts[2]]
                type = parts[3] if type is 'custom'
                @currentContact.datapoints.push
                    name: 'other', type: type, value: value

    # handle multi-lines DP (custom label)
    handleComposedLine: (line) ->
        [all, itemidx, part, value] = line.match regexps.composedkey

        if @currentIndex is null or @currentIndex isnt itemidx
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
                key = 'other'

            if key is 'adr'
                if Array.isArray value
                    value = value.map VCardParser.unescapeText
                else
                    value = ['', '', VCardParser.unescapeText(value),
                    '', '', '', '']

            @currentDatapoint['name'] = key.toLowerCase()
            @currentDatapoint['value'] = value

    handleComplexLine: (line) ->
        [all, key, properties, value] = line.match regexps.complex

        @storeCurrentDatapoint()
        @currentDatapoint = {}

        value = value.split ';'
        value = value[0] if value.length is 1

        key = key.toLowerCase()

        if key in ['email', 'tel', 'adr', 'url']
            @currentDatapoint['name'] = key
            if key is 'adr'
                if Array.isArray value

                    value = value.map VCardParser.unescapeText
                else
                    value = ['', '', VCardParser.unescapeText(value),
                    '', '', '', '']

        else if key is 'bday'
            @currentContact['bday'] = value
            @currentDatapoint = null
            return
        else if key is 'photo'
            # photo is a special field, not marked as a datapoint
            @currentContact['photo'] = value
            @currentDatapoint = null
            return
        else
            #@TODO handle unkwnown keys
            @currentDatapoint = null
            return

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
                pvalue = pvalue.toLowerCase()

            else if property is 'PREF'
                pname = 'pref'
                pvalue = true

            else
                pname = 'type'
                pvalue = property.toLowerCase()

            # iOS use type=pref instead of pref=123.
            if pname is 'type' and pvalue is 'pref'
                pname = 'pref'
                pvalue = true

            # Google, iOS use many type fields.
            # We decide home, work, cell have priotiry over others.
            if pname is 'type'
                @addTypeProperty dp, pvalue

            else
                dp[pname.toLowerCase()] = pvalue

    # Google, iOS use many type fields.
    # We decide home, work, cell have priotiry over others.
    addTypeProperty: (dp, pvalue) ->
        pname = 'type'
        if 'type' of dp
            pname = 'type-2'

            # It has priority
            if pvalue in ['home', 'work', 'cell']
                oldTypeValue = dp.type
                dp.type = pvalue
                pvalue = oldTypeValue

        dp[pname.toLowerCase()] = pvalue





VCardParser.unquotePrintable = (s) ->
    s = s or ''
    try
        return utf8.decode quotedPrintable.decode s
    catch error
        # Error decoding,
        return s

VCardParser.escapeText = (s) ->
    if not s?
        return s
    t = s.replace /([,;\\])/ig, "\\$1"
    t = t.replace /\n/g, '\\n'

    return t

VCardParser.unescapeText = (t) ->
    if not t?
        return t
    s = t.replace /\\n/ig, '\n'
    s = s.replace /\\([,;\\])/ig, "$1"

    return s


VCardParser.toVCF = (model, picture = null) ->
    out = ["BEGIN:VCARD"]
    out.push "VERSION:3.0"

    uri = model.carddavuri
    uid = uri?.substring(0, uri.length - 4) or model.id
    out.push "UID:#{uid}"

    for prop in ['fn', 'bday', 'org', 'title', 'note']
        value = model[prop]
        value = VCardParser.escapeText value if value
        out.push "#{prop.toUpperCase()}:#{value}" if value


    if model.n?
        out.push "N:#{model.n}"

    for i, dp of model.datapoints
        key = dp.name.toUpperCase()
        type = dp.type?.toUpperCase() or null
        value = dp.value

        if Array.isArray value
            value = value.map VCardParser.escapeText
        else
            value = VCardParser.escapeText value

        if type?
            formattedType = ";TYPE=#{type}"
        else
            formattedType = ""

        switch key
            when 'ABOUT'
                if type in ['ORG','TITLE', 'BDAY']
                    out.push "#{formattedType}:#{value}"
                else
                    out.push "X-#{formattedType}:#{value}"
            when 'OTHER'
                out.push "X-#{formattedType}:#{value}"
            when 'ADR'
                out.push "#{key}#{formattedType}:#{value.join ';'}"
            else
                out.push "#{key}#{formattedType}:#{value}"

    if picture?
        # vCard 3.0 specifies that lines must be folded at 75 characters
        # with "\n " as a delimiter
        folded = picture.match(/.{1,75}/g).join '\n '
        pictureString = "PHOTO;ENCODING=B;TYPE=JPEG;VALUE=BINARY:\n #{folded}"
        out.push pictureString

    out.push "END:VCARD"
    return out.join("\n") + "\n"


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
