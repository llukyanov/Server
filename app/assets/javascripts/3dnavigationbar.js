jQuery(document).ready(function($){
	var MqL = 1070;

	//toggle 3d navigation
	$('.cd-3d-nav-trigger').on('click', function(){
		toggle3dBlock(!$('.cd-header').hasClass('nav-is-visible'));
	});

	$('.cd-3d-nav-trigger-home').on('click', function(){
		toggle3dBlock(!$('.cd-header-home').hasClass('nav-is-visible'));
		//disable scrolling when 3d nav bar drops down
		if ($('.cd-header-home').hasClass('nav-is-visible')) {
			$(document).bind('touchmove', function(e) {
    			e.preventDefault();
			});
		}else{
			$(document).unbind('touchmove');
		}
	});

	//select a new item from the 3d navigation
	$('.cd-3d-nav').on('click', 'a', function(){
		var selected = $(this);
		selected.parent('li').addClass('cd-selected').siblings('li').removeClass('cd-selected');
		updateSelectedNav('close');
	});

	$(window).on('resize', function(){
		window.requestAnimationFrame(updateSelectedNav);
	});


	function toggle3dBlock(addOrRemove) {
		if(typeof(addOrRemove)==='undefined') addOrRemove = true;	
		$('.cd-header').toggleClass('nav-is-visible', addOrRemove);
		$('.cd-header-home').toggleClass('nav-is-visible', addOrRemove);
		$('.cd-3d-nav-container').toggleClass('nav-is-visible', addOrRemove);
		$('.pushdown2').toggleClass('nav-is-visible', addOrRemove).one('webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend', function(){
			//fix marker position when opening the menu (after a window resize)
			addOrRemove && updateSelectedNav();
		});
		$('.home-container').toggleClass('nav-is-visible', addOrRemove).one('webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend', function(){
			//fix marker position when opening the menu (after a window resize)
			addOrRemove && updateSelectedNav();
		});
		$('.features-container').toggleClass('nav-is-visible', addOrRemove).one('webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend', function(){
			//fix marker position when opening the menu (after a window resize)
			addOrRemove && updateSelectedNav();
		});
		$('.legal-container').toggleClass('nav-is-visible', addOrRemove).one('webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend', function(){
			//fix marker position when opening the menu (after a window resize)
			addOrRemove && updateSelectedNav();
		});
	}

	//this function update the .cd-marker position
	function updateSelectedNav(type) {
		try {
			var selectedItem = $('.cd-selected'),
				selectedItemPosition = selectedItem.index() + 1, 
				leftPosition = selectedItem.offset().left,
				backgroundColor = selectedItem.data('color'),
				marker = $('.cd-marker');

			marker.removeClassPrefix('color').addClass('color-'+ selectedItemPosition).css({
				'left': leftPosition,
			});
			if( type == 'close') {
				marker.one('webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend', function(){
					toggle3dBlock(false);
				});
			}
		}
		catch(err) {
			null
		}

	}

	$.fn.removeClassPrefix = function(prefix) {
	    this.each(function(i, el) {
	        var classes = el.className.split(" ").filter(function(c) {
	            return c.lastIndexOf(prefix, 0) !== 0;
	        });
	        el.className = $.trim(classes.join(" "));
	    });
	    return this;
	};
});