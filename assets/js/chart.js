import d3 from 'd3';
import c3 from 'c3';

export default function() {
  window.addEventListener("DOMContentLoaded", function() {
    if(document.getElementById("chart-prediction-accuracy")) {
      setupDashboard();
    }
  });
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
