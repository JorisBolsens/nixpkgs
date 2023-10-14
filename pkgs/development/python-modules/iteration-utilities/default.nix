{ lib, buildPythonPackage, fetchFromGitHub
, pytestCheckHook
}:

buildPythonPackage rec {
  pname = "iteration-utilities";
  version = "0.12.0";

  src = fetchFromGitHub {
    owner = "MSeifert04";
    repo = "iteration_utilities";
    rev = "refs/tags/v${version}";
    hash = "sha256-KdL0lwlmBEG++JRociR92HdYxzArTeL5uEyUjvvwi1Y=";
  };

  nativeCheckInputs = [
    pytestCheckHook
  ];

  pythonImportsCheck = [ "iteration_utilities" ];

  meta = with lib; {
    description = "Utilities based on Pythons iterators and generators";
    homepage = "https://github.com/MSeifert04/iteration_utilities";
    license = licenses.asl20;
    maintainers = with maintainers; [ jonringer ];
  };
}
