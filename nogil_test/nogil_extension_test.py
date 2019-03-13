from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

setup(
    ext_modules = cythonize([
        Extension(
            'nogil_extension',
            language='c++',
            sources=['nogil_extension.pyx'],
            extra_compile_args=["-pthread", "-std=c++11"],
        ),
    ])
)
