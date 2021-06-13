/* see originalsrc folder for license*/
var card = document.querySelector('.js-profile-card');

var app = angular.module('IntensifierAUv3', []);

app.controller('IntensifierCtrl', function($scope) {
});

app.directive('slider', function () {
	return {
		restrict: 'A',
		template: `
			<div class="slider-label">{{ label }}</div>
			<div class="slider-bar"></div>
			<div class="slider-handle"></div>
			<div class="slider-value">{{ control | number:decimals }}</div>
		`,
		scope: {
			'label': '@',
			'minvalue': '=',
			'maxvalue': '=',
			'control': '=',
			'decimals': '=',
			'update': '&'
		},
		link: function (scope, element, attrs) {
			var handle;
			var sliderbar;
			var percent_offset;
			var handle_offset;
			
			function positionHandle(position) {
				handle.css({
					left: position + 'px',
				});			
			}
			
			function initialize () {
				handle = element.find('.slider-handle');
				sliderbar = element.find('.slider-bar');
				percent_offset = (scope.control - scope.minvalue) / (scope.maxvalue - scope.minvalue);
				handle_offset = percent_offset * sliderbar[0].offsetWidth;				
				positionHandle(handle_offset);
			}
			
			initialize();
			
			function getPosition (event) {
				var position = 0;
				if (event.type == 'mousedown' || event.type == 'mousemove') {
					position = event.pageX - sliderbar.offset().left;
				} else if (event.type == 'touchstart' || event.type == 'touchmove') {
					position = event.originalEvent.touches[0].pageX - sliderbar.offset().left;
				}
				if (position < 0) {
					position = 0;
				} else if (position > sliderbar[0].offsetWidth) {
					position = sliderbar[0].offsetWidth;
				}
				return position;
			}
			
			element.on('mousedown touchstart', function (event) {
				var position = getPosition(event);
				scope.moving = true;
				positionHandle(position);
				var newvalue = (position / sliderbar[0].offsetWidth) * (scope.maxvalue - scope.minvalue) + scope.minvalue;
				scope.control = newvalue;
				window.webkit.messageHandlers.typeListener.postMessage(handle[0].parentElement.attributes[2].nodeValue);
                window.webkit.messageHandlers.valueListener.postMessage(scope.control);
				scope.update();
				scope.$apply();
			});
			$(window).on('mousemove touchmove', function (event) {
				if (scope.moving) {
					var position = getPosition(event);
					positionHandle(position);
					var newvalue = (position / sliderbar[0].offsetWidth) * (scope.maxvalue - scope.minvalue) + scope.minvalue;
					scope.control = newvalue;
					window.webkit.messageHandlers.typeListener.postMessage(handle[0].parentElement.attributes[2].nodeValue);
                    window.webkit.messageHandlers.valueListener.postMessage(scope.control);
					scope.update();
					scope.$apply();
				}
			});
			$(window).on('mouseup touchend', function (event) {
				scope.moving = false;
			});
			
			scope.$watch('control', function () {
				initialize();
			});
		}
	}
});

app.directive('toggle', function () {
	return {
		restrict: 'A',
		template: `
			<div class="toggle-label">{{ label }}</div>
			<div class="toggle-container" ng-class="{'toggle-off': !property}">
				<div class="toggle-handle"></div>
			</div>
		`,
		scope: {
			'label': '@',
			'property': '=',
		},
		link: function (scope, element, attrs) {
			element.on('click', function () {
				scope.property = !scope.property;
				scope.$apply();
			});
		}
	}
});
