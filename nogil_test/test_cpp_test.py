from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

setup(
    ext_modules = cythonize([
        Extension(
            'test_cpp',
            language='c++',
            sources=['test_cpp.pyx'],
            extra_compile_args=["-pthread", "-std=c++11"],
        ),
    ])
)
