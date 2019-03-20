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
}

export function setupDashboard() {
  var rawData = window.dataPredictionAccuracyJSON;
  var prodAccs = rawData["prod_accs"];
  var dgAccs = rawData["dg_accs"];
  var dateRangeData = rawData["buckets"];
  var chartType = rawData["chart_type"];
  var chartHeight;
  var dataType;
  var rotateAxes;
  var xAxisText;
  var xAxisType;
  var xAxisRotation;

  switch(chartType) {
    case "Hourly": {
      chartHeight = 540;
      dataType = "line";
      rotateAxes = false;
      xAxisText = "Hour of Day";
      xAxisType = "indexed";
      xAxisRotation = 0;
      break;
    }
    case "Daily": {
      chartHeight = 540;
      dataType = "line";
      rotateAxes = false;
      xAxisText = "";
      xAxisType = "timeseries";
      xAxisRotation = 75;
      break;
    }
    case "By Station": {
      chartHeight = prodAccs.length * 25;
      dataType = "bar";
      rotateAxes = true;
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
      rotated: rotateAxes,
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
      height: chartHeight
    },
    legend: {
      position: "inset"
    }
  });
}
