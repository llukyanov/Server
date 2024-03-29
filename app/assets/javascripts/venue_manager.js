$('#jsi-nav').sidebar({
  trigger: '.jsc-sidebar-trigger',
  scrollbarDisplay: true,
  pullCb: function () { 
    if(!$('.jsc-sidebar-content').hasClass('jsc-sidebar-pushed')) {
      $('#hamburger-menu-button').removeClass('active');  
    }
  },
  pushCb: function () {
    if($('.jsc-sidebar-content').hasClass('jsc-sidebar-pushed')) {
      $('#hamburger-menu-button').addClass('active');  
    }
  }
});

var venue_messages = {
  add_fields: function(link, association, content, selector) {
    var current_size = $('.list-group.venue_messages_list.messages_list li:visible').size();
    if(current_size < 4) {
      var new_id = new Date().getTime();
      var regexp = new RegExp('new_' + association, 'g')
      $(selector).append(content.replace(regexp, new_id)); 
      // $("a[rel~=tooltip], .has-tooltip").tooltip();
    }
    $('.delete_button').confirmation()
    venue_messages.update_section();
  },
  update_section: function() {
    var current_size = $('.list-group.venue_messages_list.messages_list li:visible').size();
    if(current_size >= 4) {
      $('.list-group.venue_messages_list.add_to_list').addClass('hide');
    } else {
      $('.list-group.venue_messages_list.add_to_list').removeClass('hide');
    }
  },
  assign_positions: function() {
    $(".messages_list li.list-group-item").each(function(index, element) {
      $(this).find('.position').val(index);
    })
    return false;
  },
  delete_message: function(element) {
    $(element).parent().find('input[type=hidden]').val('1');
    $(element).closest('.fields').hide();
    venue_messages.update_section();
  }
}

function open_contact_us() {
  $('#contact_us_modal').modal('show');
  return false;
}

$(function(){
  if($('body').hasClass('venue_manager')) {  
    $('.marquee').marquee();
    $('#display_menu_opt').change(function(event) {
      if($(this).is(':checked')) {
        $('.display_menu').removeClass('no_link').removeClass('link').addClass('add_link');
      } else {
        $('#venue_menu_link').val('');
        $('.display_menu').removeClass('add_link').removeClass('link').addClass('no_link');
      }
    });
    $('.display_menu .btn-edit').click(function(){
      $('.display_menu').removeClass('no_link').removeClass('link').addClass('add_link');
      return false;
    })
    $('.venue_messages_list.messages_list input[type="hidden"]').each(function(){
      $(this).prev().append($(this));
    });
    $('#messages_list').sortable({
      handle: ".move_handle",
      update: function(event, ui) {
        if($(".list-group-item:visible .edit input[type=text]").length > 0) {
            $(".venue_message").html($(".list-group-item:visible .edit input[type=text]")[0].value);
        } else {
            $(".venue_message").html("");
        }
      }
    });
    $('.venue-selector a').click(function(){
      $('.modal-backdrop').show().delay(800).addClass('in');
      $('.venue-selector-container ul.list-group').show();
      return false;
    });
    $('.venue-selector-container ul.list-group li a, .modal-backdrop').click(function(e){
      $('.modal-backdrop').removeClass('in').delay(800);
      $('.venue-selector-container ul.list-group').hide();
      setTimeout(function(){ $('.modal-backdrop').css('display','none'); }, 800);
    });
    $('.messages_list').on('click', '.delete_button', function() {
      $('#delete_message_modal').modal('show');
      element = this
      $('#delete_message_modal .btn-danger').unbind().click(function(){
        venue_messages.delete_message(element);
        $('#delete_message_modal').modal('hide');
      })
      return false;
    });
    $('.messages_list').on('click', '.message_items .view', function() {
      $(this).parent().find('.edit').removeClass('hide');
      $(this).parent().find('.edit input').focus();
      $(this).addClass('hide');
    });
    $('.messages_list').on('blur', '.message_items .edit input', function() {
      var val = $.trim($(this).val())
      $(this).val(val);
      if($.trim($(this).val()) == "") {

      } else {
        $(this).parent().parent().find('.view').removeClass('hide');
        $(this).parent().parent().find('.view').html(val);
        $(this).parent().addClass('hide');  
      }
    });
    $('.messages_list').on('keyup', '.message_items .edit input', function() {
      var val = $.trim($(this).val())
      $(this).closest('.list-group-item.fields').find('.character_limit')
      $(this).closest('.list-group-item.fields').find('.character_limit span').html(val.length);
    });
  }
})