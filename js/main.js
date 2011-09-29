(function() {
  var hide_unfinished_sections;
  hide_unfinished_sections = function(options) {
    if (options == null) {
      options = {};
    }
    _(options.nav_sections).each(function(section) {
      $("nav a[href='#" + section + "']").closest('li').remove();
      return $("article#" + section).closest('div').remove();
    });
    if (options.contact_blurb) {
      $('#formstatus').prevUntil('hr').prevAll('h3,p').remove();
      $('#formstatus').prevUntil('hr').remove();
    }
    if (options.email_form) {
      $('#formstatus').prev('h3').remove();
      return $('#formstatus,#form').remove();
    }
  };
  hide_unfinished_sections({
    nav_sections: ['portfolio', 'github'],
    email_form: true,
    contact_blurb: false
  });
}).call(this);
