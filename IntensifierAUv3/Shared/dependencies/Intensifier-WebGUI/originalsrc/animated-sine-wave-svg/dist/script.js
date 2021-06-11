var app = angular.module('waveApp', []);

app.controller('waveCtrl', function($scope) {
	
	var path = $('.sine-wave');
	var reference = $('.sine-wave-reference');

	$scope.x = 0;
	$scope.offset = 0;
	
	$scope.reset = function () {
		$scope.frequency = 0.25;
		$scope.amplitude = 1;
		$scope.shadow = true;
		$scope.framerate = 60;
		$scope.increment = 5;
		$scope.rotation = 0;
	};

	$scope.reset();
	
	$scope.pathFunction = function (x) {
		var result = 
			
			// Function to determine curve
			// 0.2*(Math.sin(Math.sqrt(x)-$scope.offset))*x;
			(Math.sin(Math.sqrt(x*$scope.frequency)-$scope.offset))*x*(0.1 * $scope.amplitude);
		
		return result;
	};
	
	$scope.createGraph = function (wave) {
		$scope.x = 0;
		var data = [
			{
				'type': 'M',
				'values': [0,150]
			}
		];
		while ($scope.x < 300) {
			point = {
				x: $scope.x,
				y: 150 - $scope.pathFunction($scope.x) 
			};
			data.push({
				'type': 'L',
				'values': [
					point.x,
					point.y
				]
			});
			$scope.x += 1;
		}
		wave[0].setPathData(data);
	};
	
	$scope.createGraph(reference);
	
	$scope.updateGraph = function () {
		$scope.createGraph(reference);
	};
	
	$scope.play = true;

	$scope.animate = function () {
		if ($scope.play === true) {
			$scope.offset += ($scope.increment / $scope.framerate);
			$scope.createGraph(path);
			setTimeout(function () {
				requestAnimationFrame($scope.animate);	
			},(1000 / $scope.framerate));
		}
	}
	requestAnimationFrame($scope.animate);
	
	
	$scope.togglePlay = function () {
		$scope.play = !$scope.play;
		if ($scope.play === true) {
			$scope.animate();
		}
	};
	
	$scope.stepForward = function () {
		$scope.offset += 0.5;
		$scope.createGraph(path);
	};

	$scope.stepBack = function () {
		$scope.offset -= 0.5;
		$scope.createGraph(path);
	};
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
				scope.update();
				scope.$apply();
			});
			$(window).on('mousemove touchmove', function (event) {
				if (scope.moving) {
					var position = getPosition(event);
					positionHandle(position);
					var newvalue = (position / sliderbar[0].offsetWidth) * (scope.maxvalue - scope.minvalue) + scope.minvalue;
					scope.control = newvalue;
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