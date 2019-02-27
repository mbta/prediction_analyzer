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

  document.getElementById('link-hourly').addEventListener('click', function(event) {
    event.preventDefault();
    chartRangeInput.value = 'Hourly';
    accuracyForm.submit();
  });
  document.getElementById('link-daily').addEventListener('click', function(event) {
    event.preventDefault();
    chartRangeInput.value = 'Daily';
    accuracyForm.submit();
  });

  var routeButtonElements = document.getElementsByClassName('route-button');
  for (var i = 0; i < routeButtonElements.length; i++) {
    routeButtonElements[i].addEventListener('click', function(event) {
      event.preventDefault();
      routeIdInput.value = this.text;
      if (this.text === 'All lines') {
	routeIdInput.value = '';
      }
      else {
	var words = this.text.split(' ');
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
  var dateRangeData = rawData["time_buckets"];
  var chartType = rawData["chart_type"];

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
      ]
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
        label: {
          text: (chartType === "Hourly" ? "Hour of Day" : ""),
          position: "outer-center"
        },
        type: (chartType === "Hourly" ? 'indexed' : 'timeseries'),
        tick: {
          rotate: (chartType === "Hourly" ? 0 : 75),
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
      height: 400
    },
    legend: {
      position: "inset"
    }
  });
}
