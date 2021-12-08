Cython+ - Multi-core concurrent programming in Python
======================================================

.. warning::
    This is the README for the `Cython+ <https://cython.plus/>`_.
    Since Cython+ is heavily based on `Cython <https://cython.org/>`_,
    you may with to read also the `README for Cython <./README-Cython.rst>`_.*


What's Cython?
--------------

The aim of the "Cython+" project is to ensure that all the cores
of a microprocessor can be efficiently exploited with a program
written in Python in the field of system or network programming,
so as to correct the main shortcoming of the Python language and
increase the competitiveness of its ecosystem.  The envisaged
approach consists in transferring the extremely powerful multi-core
concurrent programming model of the Go language to the Python
language by relying on innovative scientific and technological
approaches stemming from three decades of French know-how in the
field of concurrent object programming around `Actalk
<http://www-poleia.lip6.fr/~briot/actalk/actalk.html>`_, and
leveraging the existing `Cython <https://cython.org/>`_ language.

Cython is actually a superset of the Python language that brings
together the strong typing of Python, performance equivalent to C
and a form of low-level parallelism well suited to scientific
computing. It is with Cython that the `scikit-learn
<https://scikit-learn.org/stable/>`_ libraries or certain components
of the NEO transactional distributed database are developed. Cython
corrects the shortcomings of the Python language in terms of typing
or performance. Cython also corrects the Global Interpreter Lock
(GIL) problem which is at the origin of the poor support of multi-core
microprocessors in Python.

In the "Cython+" project, we propose to remove the GIL in a very
specific way: only at the level of asynchronous Cython functions
not calling Python objects. So nothing is changed in the Python
language nor in the "CPython" runtime which is the reference
implementation of the Python language in C. All programs already
developed in Python remain compatible. We only modify the Cython
compiler and the subpart of the Cython language disjoint from Python,
which we extend with a garbage collector and coroutines that can
be used on a multi-core architecture.

Thus, "Cython+" will offer the same kind of coroutine programming
as Go, the same level of parallelism, the same kind of memory
management, the same kind of performance, exception handling that
Go does not fully benefit from, a better concurrent programming
model than Go, a very well-stocked standard library with much broader
community support, and guaranteed memory isolation between threads.
"Cython+" will become an alternative to Go with many advantages,
strengthening the community of the leading development language
that Python has become.


Installation and basic use
--------------------------

::

    pip install cython-plus

Then you can use the habitual Cython commands: ``cython``, ``cythonize`` and
``cygdb``, as well as import the ``cython`` module from your Python code.


Documentation
-------------

- Project Website: <https://www.cython.plus/>

- Documentation:

  - `Motivation <https://www.cython.plus/P-CYP-Documentation.Motivation>`_
  - `Basic Syntax (by example) <https://www.cython.plus/P-CYP-Documentation.Basic.Syntax>`_
  - `Interacting with Python (by example) <https://www.cython.plus/P-CYP-Documentation.Interacting.With.Python>`_
  - `Concurrency <https://www.cython.plus/P-CYP-Documentation.Concurrency>`_

- Blog posts and articles:

  - `Automatic multithreaded-safe memory managed classes in Cython <https://www.nexedi.com/blog/NXD-Document.Blog.Cypclass>`_
  - `HowTo Use Cython+ in Jupyter Notebook <https://www.cython.plus/P-CYP-Howto.Jupyter>`_

- Sandbox (various code snippets and benchmark to help you get started): <https://github.com/abilian/cythonplus-sandbox>


Development
-----------

- Project repository: <https://lab.nexedi.com/nexedi/cython>
- Alternate repository (read-only): <https://github.com/abilian/cythonplus>
- CI: <https://github.com/abilian/cythonplus/actions>


License & Copyright
-------------------

Cython+ is a (friendly) fork of `Cython <https://cython.org/>`_.

Its copyright belongs to the Cython original authors (as listed
`Here <https://cython.org/#community>`_) as well as the `Cython+
consortium <https://www.cython.plus/consortium/>`_: `Nexedi
<https://nexedi.com/>`_, `Abilian <https://abilian.com/>`_, `Teralab
<https://www.teralab-datascience.fr/?lang=en>`_ and `Inria
<https://inria.fr/>`_.

Cython+ is licensed under the permissive **Apache License**. See `LICENSE.txt <./LICENSE.txt>`_.


Contributing
------------

Want to contribute to the Cython+ project?

Please contact us at <https://www.cython.plus/contact/>.


Acknowledgements
----------------

Cython+ is based on the work of the `Cython authors <https://cython.org/#community>`_.

The Cython+ project has been selected to receive funding from the PSPC-Régions 1.
It is supported by `Cap Digital <https://capdigital.com/>`_ and the `Paris Region <https://www.iledefrance.fr/>`_.
