//Associate an editor with the data_format of the body of a celina
jQuery(function($) {
    'use strict';
    let Editors = {
        $selector: 'textarea[name="body"]',
        $body_id: '_body',
        // A simple textarea
        text: function() {
            let $body = this.$selector;
            //get the value to keep it
            let $value = $($body).val();
            //empty the container
            $('#'+this.$body_id).empty();
            // recreate the textarea
            $('#'+this.$body_id).append(`<textarea name="body" required
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
        },
        markdown: function() {
            this.text();
            let editor_body = $(`#${this.$body_id}`);
            let height = editor_body.css('height');
            let editor = editormd(this.$body_id, {
                width  : 'auto',
                watch: false,
                toolbarIcons: [
                    "undo", "redo", "|", "bold", "del", "italic", "quote", "uppercase",
                    "lowercase", "|", "h1", "h2", "h3", "h4", "h5", "h6", "|",
                    "list-ul", "list-ol", "hr", "|", "link", "reference-link", "image",
                    "code", "code-block", "table",
                    "watch", "preview", "fullscreen", "|", "help", "info"
        ],
                path    : '/js/editormd/lib/'
            });
            editor.editor.css({position: 'relaive', top: '1rem'})
            editor.editor.height(height)
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


    // Additional functionality - hiding and showing fieldsets in stranici and
    // celini forms.
    $(".mui-form>fieldset>legend").click(function() {
      let self = this;
      let rows = $(".mui-row", this.parentNode);
      let errors = $(".mui-row .field-with-error", this.parentNode);
      // Hide fieldsets only if there are no validation errors
      if (rows.is(":visible") && errors.get(0) == null) {
        rows.hide(600, function() {
          let text = $(self).text();
          if (!text.match(/…$/)) $(self).text($(self).text() + "…");
        });
      } else {
        rows.show(600, function() {
          let text = $(self).text();
          $(self).text(text.replace(/…/, ""));
        });
      }
    });

    // hide Permissions and additional fields by default.
    $(".mui-form>fieldset:nth-of-type(2)>legend").click();
    $(".mui-form>fieldset:nth-of-type(3)>legend").click();

});
