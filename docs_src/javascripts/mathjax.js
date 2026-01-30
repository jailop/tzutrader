// MathJax configuration for rendering mathematical formulas in documentation
window.MathJax = {
  tex: {
    inlineMath: [['$', '$'], ['\\(', '\\)']],
    displayMath: [['$$', '$$'], ['\\[', '\\]']],
    processEscapes: true,
    processEnvironments: true
  },
  options: {
    ignoreHtmlClass: '.*|',
    processHtmlClass: 'arithmatex'
  }
};

document$.subscribe(() => {
  MathJax.typesetPromise();
});
