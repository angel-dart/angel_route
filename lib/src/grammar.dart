part of angel_route.src.router;

class RouteGrammar {
  static final Parser<String> notSlash =
      match<String>(new RegExp(r'[^/]+')).value((r) => r.span.text);

  static final Parser<RegExp> regExp = match<RegExp>(new RegExp(r'\((.+)\)'))
      .value((r) => new RegExp(r.scanner.lastMatch[1]));

  static final Parser<String> parameterName =
      match<String>(new RegExp(r':([A-Za-z0-9_]+)'))
          .value((r) => r.span.text.substring(1));

  static final Parser<ParameterSegment> parameterSegment = chain([
    parameterName,
    match('?').value((r) => true).opt(),
    regExp.opt(),
  ]).map((r) {
    var s = new ParameterSegment(r.value[0] as String, r.value[2] as RegExp);
    return r.value[1] == true ? new OptionalSegment(s) : s;
  });

  static final Parser<ParsedParameterSegment> parsedParameterSegment = chain([
    match(new RegExp(r'(int|num|double)'),
            errorMessage: 'Expected "int","double", or "num".')
        .map((r) => r.span.text),
    parameterSegment,
  ]).map((r) {
    return new ParsedParameterSegment(
        r.value[0] as String, r.value[1] as ParameterSegment);
  });

  static final Parser<WildcardSegment> wildcardSegment =
      match<WildcardSegment>('*').value((r) => new WildcardSegment());

  static final Parser<ConstantSegment> constantSegment =
      notSlash.map<ConstantSegment>((r) => new ConstantSegment(r.value));

  static final Parser<RouteSegment> routeSegment = any<RouteSegment>([
    parsedParameterSegment,
    parameterSegment,
    wildcardSegment,
    constantSegment
  ]);

  static final Parser<RouteDefinition> routeDefinition = routeSegment
      .separatedBy(match('/'))
      .map((r) => new RouteDefinition(r.value ?? []))
      .surroundedBy(match('/').star().opt());
}

class RouteDefinition {
  final List<RouteSegment> segments;

  RouteDefinition(this.segments);

  Parser<Map<String, dynamic>> compile() {
    Parser<Map<String, dynamic>> out;

    for (int i = 0; i < segments.length; i++) {
      var s = segments[i];
      bool isLast = i == segments.length - 1;
      if (out == null)
        out = s.compile(isLast);
      else
        out = s.compileNext(
            out.then(match('/')).index(0).cast<Map<String, dynamic>>(), isLast);
    }

    return out;
  }
}

abstract class RouteSegment {
  Parser<Map<String, dynamic>> compile(bool isLast);

  Parser<Map<String, dynamic>> compileNext(
      Parser<Map<String, dynamic>> p, bool isLast);
}

class ConstantSegment extends RouteSegment {
  final String text;

  ConstantSegment(this.text);

  @override
  String toString() {
    return 'Constant: $text';
  }

  @override
  Parser<Map<String, dynamic>> compile(bool isLast) {
    return match<Map<String, dynamic>>(text).value((r) => <String, dynamic>{});
  }

  @override
  Parser<Map<String, dynamic>> compileNext(
      Parser<Map<String, dynamic>> p, bool isLast) {
    return p.then(compile(isLast)).index(0).cast<Map<String, dynamic>>();
  }
}

class WildcardSegment extends RouteSegment {
  @override
  String toString() {
    return 'Wildcard segment';
  }

  Parser<Map<String, dynamic>> _compile(bool isLast) {
    if (isLast) return match(new RegExp(r'.*'));
    return match(new RegExp(r'[^/]*'));
  }

  @override
  Parser<Map<String, dynamic>> compile(bool isLast) {
    return _compile(isLast).map((r) => {});
  }

  @override
  Parser<Map<String, dynamic>> compileNext(
      Parser<Map<String, dynamic>> p, bool isLast) {
    return p.then(_compile(isLast)).index(0).cast<Map<String, dynamic>>();
  }
}

class OptionalSegment extends ParameterSegment {
  final ParameterSegment parameter;

  OptionalSegment(this.parameter) : super(parameter.name, parameter.regExp);

  @override
  String toString() {
    return 'Optional: $parameter';
  }

  @override
  Parser<Map<String, dynamic>> compile(bool isLast) {
    return super.compile(isLast).opt();
  }

  @override
  Parser<Map<String, dynamic>> compileNext(
      Parser<Map<String, dynamic>> p, bool isLast) {
    return p.then(_compile().opt()).map((r) {
      if (r.value[1] == null) return r.value[0] as Map<String, dynamic>;
      return (r.value[0] as Map<String, dynamic>)
        ..addAll({name: Uri.decodeComponent(r.value[1] as String)});
    });
  }
}

class ParameterSegment extends RouteSegment {
  final String name;
  final RegExp regExp;

  ParameterSegment(this.name, this.regExp);

  @override
  String toString() {
    if (regExp != null) return 'Param: $name (${regExp.pattern})';
    return 'Param: $name';
  }

  Parser<String> _compile() {
    return regExp != null
        ? match<String>(regExp).value((r) => r.span.text)
        : RouteGrammar.notSlash;
  }

  @override
  Parser<Map<String, dynamic>> compile(bool isLast) {
    return _compile().map<Map<String, dynamic>>(
        (r) => {name: Uri.decodeComponent(r.span.text)});
  }

  @override
  Parser<Map<String, dynamic>> compileNext(
      Parser<Map<String, dynamic>> p, bool isLast) {
    return p.then(_compile()).map((r) {
      return (r.value[0] as Map<String, dynamic>)
        ..addAll({name: Uri.decodeComponent(r.value[1] as String)});
    });
  }
}

class ParsedParameterSegment extends RouteSegment {
  final String type;
  final ParameterSegment parameter;

  ParsedParameterSegment(this.type, this.parameter);

  num getValue(String s) {
    switch (type) {
      case 'int':
        return int.parse(s);
      case 'double':
        return double.parse(s);
      default:
        return num.parse(s);
    }
  }

  @override
  Parser<Map<String, dynamic>> compile(bool isLast) {
    return parameter._compile().map(
        (r) => {parameter.name: getValue(Uri.decodeComponent(r.span.text))});
  }

  @override
  Parser<Map<String, dynamic>> compileNext(
      Parser<Map<String, dynamic>> p, bool isLast) {
    return p.then(parameter._compile()).map((r) {
      return (r.value[0] as Map<String, dynamic>)
        ..addAll({
          parameter.name: getValue(Uri.decodeComponent(r.value[1] as String))
        });
    });
  }
}