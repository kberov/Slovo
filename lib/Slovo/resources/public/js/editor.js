//Associate an editor with the data_format of the body of a celina
jQuery(function($) {
    'use strict';
    let Editors = {
        $selector: 'textarea[name="body"]',
        // A simple textarea
        text: function() {
            let $body = this.$selector;
            //get the value to keep it
            let $value = $($body).val();
            //empty the container
            $('#_body').empty();
            // recreate the textarea
            $('#_body').append(`<textarea name="body" required
            style="width:100%;height:25em"></textarea>`);
            $($body).val($value);
        },
        //Apply a html editor to the textareaea
        html: function() {
            this.text();
            $(this.$selector).trumbowyg({
                btns: [
                    ['viewHTML'],
                    ['undo', 'redo'], // Only supported in Blink browsers
                    ['formatting'],
                    ['strong', 'em', 'del'],
                    ['superscript', 'subscript'],
                    ['link'],
                    ['insertImage', 'base64'],
                    ['justifyLeft', 'justifyCenter', 'justifyRight', 'justifyFull'],
                    ['unorderedList', 'orderedList'],
                    ['horizontalRule'],
                    ['removeformat'],
                    ['fullscreen']
                ],
                removeformatPasted: true,
                lang: 'bg'
            });
        }
    }; // End Editors

    let $format_s = $('[name="data_format"]');
    let $v = $format_s.val();
    if (Editors.hasOwnProperty($v)) Editors[$v]();
    else   Editors.text();

    function switch_editors() {
        let $v = this.value;
        if (Editors.hasOwnProperty($v)) Editors[$v]();
        else
            Editors.text();
    }

    $format_s.on('change', switch_editors);
    //
});
