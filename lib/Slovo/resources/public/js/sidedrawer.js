jQuery(function($) {
'use strict';
  var $bodyEl = $('body'),
      $sidedrawerEl = $('#sidedrawer');

  function showSidedrawer() {
    // show overlay
    var options = {
      onclose: function() {
        $sidedrawerEl
          .removeClass('active')
          .appendTo(document.body);
      }
    };

    var $overlayEl = $(mui.overlay('on', options));

    // show element
    $sidedrawerEl.appendTo($overlayEl);
    setTimeout(function() {
      $sidedrawerEl.addClass('active');
    }, 20);
  }

  function hideSidedrawer() {
    $bodyEl.toggleClass('hide-sidedrawer');
  }

  $('.js-show-sidedrawer').on('click', showSidedrawer);
  $('.js-hide-sidedrawer').on('click', hideSidedrawer);

/**
 * Expand the folder and load the list of subpages
 */
var $titleEls = $('.folder-expander', $sidedrawerEl);

$titleEls
  .next()
  .hide();

$titleEls.on('click', folder_expaner_onclick);

/**
 * Assigns onclick events to matched elements.
 */
function folder_expaner_onclick ($ev) {
    $ev.stopPropagation();
    $ev.preventDefault();
    let $parent = $(this).parent().parent();
    let $submenu = $('ul', $parent);
    // if the list is already retreived, just toggle
    if($submenu.get(0) !== undefined) {
        $('ul', $parent).slideToggle(200);
        return;
    }
    let $api_url = $(this).attr('href');
    get_страници($api_url,$parent);
    $submenu.slideToggle(200);
}

/**
 * Gets the list of pages from $url and appends them to $parent.
 */
function get_страници ($url, $parent) {
    let $url_no_qs = $url.split(/[?]/)[0];
    $.getJSON($url).done(function($data){
        if($data.length === 0) {
            let $self_href = $('a:first-child', $parent).attr('href');
            $parent.append(`<ul><li><div><a href="${$self_href}">.</a></div></li></ul>`);
            return;
        }
        $('<ul>').appendTo($parent);
        $data.forEach(function($row){
            let $page_url = `/${$row.alias}.${$row.language}.html`;
            let $page_link = `<a href="${$page_url}">${$row.title}</a>`;
            let $expander_url = '',
                $expander_link =  '',
                $item = `<div>${$page_link}${$expander_link}</div>`;
            if($row.is_dir === 1) {
                $expander_url = $url_no_qs + '?'
                    + $.param({pid: $row.id, 'lang': $row.language});
                $expander_link = `<a id="id${$row.id}"
                    href="${$expander_url}" class="folder-expander mui--pull-right">☰</a>`;
                $item = `<strong>${$page_link}${$expander_link}</strong>`;
                let $li = $('ul', $parent).append(`<li>${$item}</li>`);
                $(`#id${$row.id}`, $li).on('click', folder_expaner_onclick);
                return;
            }
            $('ul', $parent).append(`<li>${$item}</li>`);
        });
    });
}
});
