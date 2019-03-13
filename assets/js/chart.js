import d3 from 'd3';
import c3 from 'c3';

export default function() {
  window.addEventListener("DOMContentLoaded", function() {
    if(document.getElementById("chart-prediction-accuracy")) {
      setupDashboard();
    }

    var accuracyForm = document.getElementsByClassName('accuracy-form')[0];
    if(accuracyForm) {
      bindFormLinks(accuracyForm);
    }
  });
}

export function bindFormLinks(accuracyForm) {
  var chartRangeInput = document.getElementById('filters_chart_range');
  var routeIdInput = document.getElementById('filters_route_id');

  var bindChartRangeLink = function(linkId, inputValue) {
    document.getElementById(linkId).addEventListener('click', function(event) {
      event.preventDefault();
      chartRangeInput.value = inputValue;
      accuracyForm.submit();
    });
  }

  bindChartRangeLink('link-hourly', 'Hourly');
  bindChartRangeLink('link-daily', 'Daily');
  bindChartRangeLink('link-by_station', 'By Station');

  var routeButtonElements = document.getElementsByClassName('route-button');
  for (var i = 0; i < routeButtonElements.length; i++) {
    routeButtonElements[i].addEventListener('click', function(event) {
      event.preventDefault();
      if (event.currentTarget.text === 'All lines') {
	routeIdInput.value = '';
      }
      else {
	var words = event.currentTarget.text.split(' ');
	routeIdInput.value = words[0];
      }
      accuracyForm.submit();
    });
  }
}

export function setupDashboard() {
  var rawData = window.dataPredictionAccuracyJSON;
  var prodAccs = rawData["prod_accs"];
  var dgAccs = rawData["dg_accs"];
  var dateRangeData = rawData["buckets"];
  var chartType = rawData["chart_type"];
  var dataType;
  var xAxisText;
  var xAxisType;
  var xAxisRotation;

  switch(chartType) {
    case "Hourly": {
      dataType = "line";
      xAxisText = "Hour of Day";
      xAxisType = "indexed";
      xAxisRotation = 0;
      break;
    }
    case "Daily": {
      dataType = "line";
      xAxisText = "";
      xAxisType = "timeseries";
      xAxisRotation = 75;
      break;
    }
    case "By Station": {
      dataType = "bar";
      xAxisText = "";
      xAxisType = "category";
      xAxisRotation = 90;
      break;
    }
  }

  var col_1 = ["Prod"].concat(prodAccs);
  var col_2 = ["Dev Green"].concat(dgAccs);
  var x_data = ["x"].concat(dateRangeData);

  var chart = c3.generate({
    bindto: "#chart-prediction-accuracy",
    data: {
      x: 'x',
      columns: [
        x_data,
        col_1,
        col_2,
      ],
      type: dataType
    },
    color: {
      pattern: ["#1fecff", "#c743f0"]
    },
    axis: {
      y: {
        label: {
          text: "% Accurate",
          position: "outer-middle"
        },
        max: 1,
        min: 0,
        padding: {top: 0, bottom:0},
        tick: {
          format: function(x) { return (x*100).toString() + "%";}
        }
      },
      x: {
        height: 200,
        label: {
          text: xAxisText,
          position: "outer-center"
        },
        type: xAxisType,
        tick: {
          multiline: false,
          rotate: xAxisRotation,
          culling: false
        }
      },
    },
    grid: {
      x: {
        show: true
      },
      y: {
        show: true
      }
    },
    size: {
      height: 540
    },
    legend: {
      position: "inset"
    }
  });
}
