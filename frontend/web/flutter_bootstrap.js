{{flutter_js}}
{{flutter_build_config}}

// Rebuilt local bundles must not reuse yesterday's compiled entry point.
// Hosted builds retain Flutter's normal loading and cache behaviour.
if (['localhost', '127.0.0.1', '::1'].includes(location.hostname)) {
  const version = Date.now();
  for (const build of _flutter.buildConfig.builds) {
    // The debug module loader manages its own entrypoint URLs. Version only
    // compiled release bundles here.
    if (!['dart2js', 'dart2wasm'].includes(build.compileTarget)) continue;
    for (const key of ['mainJsPath', 'mainWasmPath', 'jsSupportRuntimePath']) {
      if (build[key]) {
        build[key] += (build[key].includes('?') ? '&' : '?') + 'preview=' + version;
      }
    }
  }
}

_flutter.loader.load();
