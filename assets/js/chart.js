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

function renderDashboard() {
  var sortedProdAccs;
  var sortedDgAccs;
  var sortedBucketNames;
  var chartHeight;
  var dataType;
  var rotateAxes;
  var xAxisText;
  var xAxisType;
  var xAxisRotation;
  var sortedDataPoints;
  var sortFunction;
  var sortOrderLink;
  var sortOrder;
  var i;

  sortedProdAccs = [];
  sortedDgAccs = [];
  sortedBucketNames = [];

  if(window.sortOrderLink) {
    sortOrder = window.sortOrderLink.getAttribute("data-sort-order");
  } else {
    sortOrder = "by_id";
  }

  if(sortOrder == "by_id") {
    sortFunction = function(a, b) { return (a.id < b.id) ? -1 : 1; }
  } else {
    sortFunction = function(a, b) { return ([a.prodAcc, a.dgAcc] < [b.prodAcc, b.dgAcc]) ? -1 : 1; }
  }

  sortedDataPoints = window.dataPoints.sort(sortFunction);

  for(i = 0; i < sortedDataPoints.length; i++) {
    var dataPoint = sortedDataPoints[i];
    sortedProdAccs.push(dataPoint.prodAcc);
    sortedDgAccs.push(dataPoint.dgAcc);
    sortedBucketNames.push(dataPoint.bucket);
  }

  switch(window.chartType) {
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
      chartHeight = sortedDataPoints.length * 25;
      dataType = "bar";
      rotateAxes = true;
      xAxisText = "";
      xAxisType = "category";
      xAxisRotation = 90;
      break;
    }
  }

  var col_1 = ["Prod"].concat(sortedProdAccs);
  var col_2 = ["Dev Green"].concat(sortedDgAccs);
  var x_data = ["x"].concat(sortedBucketNames);

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

export function setupDashboard() {
  var rawData = window.dataPredictionAccuracyJSON;
  var prodAccs = rawData["prod_accs"];
  var dgAccs = rawData["dg_accs"];
  var bucketNames = rawData["buckets"];
  var i;

  window.chartType = rawData["chart_type"];
  window.dataPoints = [];

  window.sortOrderLink = document.getElementById("sort-order-link");
  if(window.sortOrderLink) {
    window.sortOrderLink.addEventListener("click", toggleSortOrder);
  }

  for(i = 0; i < bucketNames.length; i++) {
    window.dataPoints.push({
      id: i,
      bucket: bucketNames[i],
      prodAcc: prodAccs[i],
      dgAcc: dgAccs[i]
    });
  }

  renderDashboard();
}

function toggleSortOrder(event) {
  event.preventDefault();
  if(window.sortOrderLink.getAttribute("data-sort-order") == "by_id") {
    window.sortOrderLink.innerText = "Sorted By Accuracy";
    window.sortOrderLink.setAttribute("data-sort-order", "by_accuracy");
  } else {
    window.sortOrderLink.innerText = "Sorted By Route Order";
    window.sortOrderLink.setAttribute("data-sort-order", "by_id");
  }

  renderDashboard();
}
